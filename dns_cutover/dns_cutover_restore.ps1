# Requires -Modules DnsServer
# 
# Restores Microsoft DNS Server configuration from a backup created by an earlier export.
# Recreates primary, secondary, and stub zones and repopulates records for primary zones except SOA and apex NS.
# Restores conditional forwarders with replication scope and applies global forwarders while disabling root hints.
# Requires elevation and the DnsServer module, removes existing zones of the same name before re-creating them, 
# honors WhatIf and Confirm, and logs progress with timestamps. Expects CLIXML files in $BackupPath
# (zoneobj_*.xml, zone_rr_<zone>.xml, zone_condfwd_<zone>.xml, dns_global_forwarders_before.xml or dns_global_forwarders_after.xml).
# Does not restore other server wide settings such as scavenging, policies, or recursion.

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory, Position=0)]
  [ValidateScript({ Test-Path $_ -PathType Container })]
  [string]$BackupPath
)

begin {
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
  if (-not (Test-Admin)) { throw "Run in an elevated PowerShell session." }

  Import-Module DnsServer -ErrorAction Stop | Out-Null

  function Log { param([string]$m) Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" }

  function Sanitize([string]$name) { $name -replace '[^A-Za-z0-9\.\-_]', '_' }

  function Remove-IfExists([string]$zoneName) {
    $z = Get-DnsServerZone -Name $zoneName -ErrorAction SilentlyContinue
    if ($z) {
      if ($PSCmdlet.ShouldProcess($zoneName, "Remove existing zone ($($z.ZoneType))")) {
        try {
          Remove-DnsServerZone -Name $zoneName -Force
        } catch {
          Log "PowerShell removal failed, trying dnscmd for ${zoneName}"
          $null = & dnscmd.exe $env:COMPUTERNAME /zonedelete $zoneName /f
        }
      }
    }
  }

  function New-PrimaryFromObj($zoneObj) {
    $name = $zoneObj.ZoneName
    $isAD = $zoneObj.IsDsIntegrated
    if ($isAD) {
      $scope   = $zoneObj.ReplicationScope
      $dirPart = $zoneObj.DirectoryPartitionName
      $params = @{ Name = $name }
      if ($dirPart) { $params.ReplicationScope = 'Custom'; $params.DirectoryPartitionName = $dirPart }
      elseif ($scope) { $params.ReplicationScope = $scope }
      else { $params.ReplicationScope = 'Domain' }
      Add-DnsServerPrimaryZone @params | Out-Null
    } else {
      $zoneFile = $zoneObj.ZoneFile
      if ([string]::IsNullOrWhiteSpace($zoneFile)) { $zoneFile = (Sanitize $name) + '.dns' }
      Add-DnsServerPrimaryZone -Name $name -ZoneFile $zoneFile | Out-Null
    }
  }

  function New-SecondaryFromObj($zoneObj) {
    $name = $zoneObj.ZoneName
    $masters = @($zoneObj.MasterServers | Where-Object { $_ })
    if ((@($masters)).Count -eq 0) { throw "Secondary zone ${name} has no MasterServers in backup" }
    $zoneFile = $zoneObj.ZoneFile
    if ([string]::IsNullOrWhiteSpace($zoneFile)) { $zoneFile = (Sanitize $name) + '.dns' }
    Add-DnsServerSecondaryZone -Name $name -MasterServers $masters -ZoneFile $zoneFile | Out-Null
  }

  function New-StubFromObj($zoneObj) {
    $name = $zoneObj.ZoneName
    $masters = @($zoneObj.MasterServers | Where-Object { $_ })
    if ((@($masters)).Count -eq 0) { throw "Stub zone ${name} has no MasterServers in backup" }
    $zoneFile = $zoneObj.ZoneFile
    if ([string]::IsNullOrWhiteSpace($zoneFile)) { $zoneFile = (Sanitize $name) + '.dns' }
    Add-DnsServerStubZone -Name $name -MasterServers $masters -ZoneFile $zoneFile | Out-Null
  }

  function Restore-Records([string]$zoneName, [string]$rrFile) {
    if (-not (Test-Path $rrFile -PathType Leaf)) { return }
    $records = Import-Clixml -Path $rrFile
    if (-not $records) { return }

    # Skip SOA and apex NS (those come with zone creation)
    $toAdd = foreach ($rr in @($records)) {
      $rrType = [string]$rr.RecordType
      $rrHost = [string]$rr.HostName
      if ($rrType -eq 'SOA') { continue }
      if ($rrType -eq 'NS' -and ([string]::IsNullOrWhiteSpace($rrHost) -or $rrHost -eq '@')) { continue }
      $rr
    }

    foreach ($rr in @($toAdd)) {
      try {
        Add-DnsServerResourceRecord -ZoneName $zoneName -InputObject $rr -ErrorAction Stop | Out-Null
      } catch {
        Log "Failed to add record $($rr.HostName) [$($rr.RecordType)] to ${zoneName}: $($_.Exception.Message)"
      }
    }
  }

function Restore-ConditionalForwarder([string]$zoneName, [string]$cfFile, $zoneObj) {
  $cf = $null
  if (Test-Path $cfFile -PathType Leaf) { $cf = Import-Clixml -Path $cfFile }

  if ($cf) {
    $masters  = @($cf.MasterServers | Where-Object { $_ })
    $repScope = $cf.ReplicationScope
    $dirPart  = $cf.DirectoryPartitionName
  } else {
    $masters  = @($zoneObj.MasterServers | Where-Object { $_ })
    $repScope = $zoneObj.ReplicationScope
    $dirPart  = $zoneObj.DirectoryPartitionName
  }

  if ((@($masters)).Count -eq 0) { throw "Conditional forwarder ${zoneName} has no MasterServers in backup" }

  $params = @{ Name = $zoneName; MasterServers = $masters }

  # Only pass ReplicationScope for AD-integrated cases; never pass "None"
  $repScopeNorm = if ($repScope) { $repScope.ToString() } else { $null }
  switch ($repScopeNorm) {
    'Forest' { $params.ReplicationScope = 'Forest' }
    'Domain' { $params.ReplicationScope = 'Domain' }
    'Legacy' { $params.ReplicationScope = 'Legacy' }
    'Custom' {
      if ($dirPart) {
        $params.ReplicationScope = 'Custom'
        $params.DirectoryPartitionName = $dirPart
      } else {
        Log "Backup indicated Custom replication for ${zoneName} but no DirectoryPartitionName; creating LOCAL forwarder instead" 
      }
    }
    default {
      # 'None' or null => local-only; do not set ReplicationScope
    }
  }

  Add-DnsServerConditionalForwarderZone @params | Out-Null
}

}

process {
  Log "Restoring DNS from $BackupPath"

  # Restore zones from zoneobj_*.xml
  $zoneObjFiles = Get-ChildItem -Path $BackupPath -Filter 'zoneobj_*.xml' -File
  foreach ($zf in $zoneObjFiles) {
    $zoneObj = Import-Clixml -Path $zf.FullName
    $name    = $zoneObj.ZoneName
    $type    = $zoneObj.ZoneType
    Log "Restoring zone ${name} (${type})"

    Remove-IfExists $name

    switch ($type) {
      'Primary'   {
        New-PrimaryFromObj $zoneObj
        $rrPath = Join-Path $BackupPath ("zone_rr_{0}.xml" -f (Sanitize $name))
        Restore-Records -zoneName $name -rrFile $rrPath
      }
      'Secondary' { New-SecondaryFromObj $zoneObj }
      'Stub'      { New-StubFromObj      $zoneObj }
      'Forwarder' {
        $cfPath = Join-Path $BackupPath ("zone_condfwd_{0}.xml" -f (Sanitize $name))
        Restore-ConditionalForwarder -zoneName $name -cfFile $cfPath -zoneObj $zoneObj
      }
      default     { Log "Unknown zone type for ${name}: ${type}. Skipping." }
    }
  }

  # Always restore global forwarders (prefer "before", fallback to "after")
  $fwdFile = $null
  $before = Join-Path $BackupPath 'dns_global_forwarders_before.xml'
  $after  = Join-Path $BackupPath 'dns_global_forwarders_after.xml'
  if (Test-Path $before -PathType Leaf) { $fwdFile = $before }
  elseif (Test-Path $after -PathType Leaf) { $fwdFile = $after }

  if ($fwdFile) {
    try {
      $fwds = Import-Clixml -Path $fwdFile
      $rawIps = @()
      if ($fwds -is [System.Array]) {
        $rawIps = @($fwds | ForEach-Object { $_.IPAddress })
      } else {
        $rawIps = @($fwds.IPAddress)
      }
      $ips = @($rawIps | Where-Object { $_ } | ForEach-Object { $_.ToString() }) | Select-Object -Unique

      if ((@($ips)).Count -gt 0) {
        if ($PSCmdlet.ShouldProcess('Global forwarders', "Restore $($ips -join ', ')")) {
          Log "Restoring global forwarders to $($ips -join ', ')"
          [string[]]$ipArray = @($ips)
          Set-DnsServerForwarder -IPAddress $ipArray -UseRootHint $false | Out-Null
        }
      } else {
        Log "Global forwarder file '$([IO.Path]::GetFileName($fwdFile))' contains no IPs"
      }
    } catch {
      Log "Failed to restore global forwarders: $($_.Exception.Message)"
    }
  } else {
    Log "No global forwarder backup file found"
  }

  Log "Restore completed"
}
