# Requires -Modules DnsServer
#
# This script automates a DNS cutover on Windows DNS Server. Reads a CSV with zones/global settings,
# backs up server and zone state, applies changes (removals/additions/forwarders), logs all actions,
# and moves the backup folder (with log) to the current working directory for audit/handover.
# 
# example CSV:
# type,zone,addresses
# global,,"1.2.3.4,5.6.7.8"
# secondary,zone1.de,"9.8.7.6,5.4.3.2"
# secondary,zone2.de,7.6.5.4
# forwarder,zone3.de,"1.3.5.7,9.7.5.3"
# forwarder,zone4.de,5.7.9.7
#

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [ValidateScript({ Test-Path $_ -PathType Leaf })]
  [string]$CsvPath,

  [string]$BackupRoot = (Join-Path -Path ([IO.Path]::Combine([Environment]::GetFolderPath("System"), "dns")) `
                                -ChildPath ("dns_cutover_{0}" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
)

begin {
  Set-StrictMode -Version Latest
  $ErrorActionPreference = 'Stop'

  function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p  = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
  if (-not (Test-Admin)) { throw "Run this script in an elevated PowerShell session." }

  try { Import-Module DnsServer -ErrorAction Stop | Out-Null }
  catch { throw "The DnsServer module is required. Install RSAT DNS Server Tools or run on a DNS server." }

  if (-not (Test-Path $BackupRoot)) { New-Item -Path $BackupRoot -ItemType Directory | Out-Null }

  $LogPath = Join-Path $BackupRoot 'dns_cutover_actions.log'
  # Ensure backup directory and log file exist before any logging
  if (-not (Test-Path $BackupRoot)) { New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null }
  $logDir = Split-Path -Parent $LogPath
  if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  if (-not (Test-Path $LogPath)) { New-Item -ItemType File -Path $LogPath -Force | Out-Null }
  function Write-Log {
    param(
      [string]$Message,
      [ValidateSet('Info','Warn','Error')]
      [string]$Level = 'Info'
    )
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line  = "$stamp  $Message"

    switch ($Level) {
      'Warn'  { Microsoft.PowerShell.Utility\Write-Host $line -ForegroundColor Yellow }
      'Error' { Microsoft.PowerShell.Utility\Write-Host $line -ForegroundColor Red }
      default { Microsoft.PowerShell.Utility\Write-Host $line }
    }
    Write-Verbose $line
    Add-Content -Path $LogPath -Value $line
  }

  # Wrap Write-Host to also add timestamp and write to the action log
  function Write-Host {
    [CmdletBinding()]
    param(
      [Parameter(Position=0, ValueFromPipeline=$true)]
      [AllowNull()]
      $Object,
      [switch]$NoNewLine,
      $Separator,
      [System.ConsoleColor]$ForegroundColor,
      [System.ConsoleColor]$BackgroundColor
    )
    $text = [string]$Object
    if (-not $text) { $text = "" }
    # Avoid double stamping if already stamped
    if ($text -match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\s{2}') {
      $out = $text
    } else {
      $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
      $out = "$stamp  $text"
    }

    $args = @{'Object'=$out}
    if ($PSBoundParameters.ContainsKey('NoNewLine'))     { $args['NoNewLine']     = $true }
    if ($PSBoundParameters.ContainsKey('Separator'))     { $args['Separator']     = $Separator }
    if ($PSBoundParameters.ContainsKey('ForegroundColor')) { $args['ForegroundColor'] = $ForegroundColor }
    if ($PSBoundParameters.ContainsKey('BackgroundColor')) { $args['BackgroundColor'] = $BackgroundColor }

    # Write to screen using the original cmdlet
    Microsoft.PowerShell.Utility\Write-Host @args

    # Try to append to the log file as well
    try {
      if ($script:LogPath) {
        $dir = Split-Path -Parent $script:LogPath
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        Add-Content -Path $script:LogPath -Value $out
      }
    } catch { }
  }

  function Parse-AddressList {
    param([string]$List)
    if ([string]::IsNullOrWhiteSpace($List)) { return [string[]]@() }
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($raw in ($List -split ',')) {
      $addr = $raw.Trim()
      if ([string]::IsNullOrWhiteSpace($addr)) { continue }
      [IPAddress]$tmp = $null
      if (-not [System.Net.IPAddress]::TryParse($addr, [ref]$tmp)) {
        throw "Invalid IP address in CSV: '$addr'"
      }
      [void]$out.Add($tmp.IPAddressToString)
    }
    return [string[]]$out.ToArray()
  }

  function Sanitize-ZoneFileName {
    param([string]$ZoneName)
    return ($ZoneName -replace '[^A-Za-z0-9\.\-_]', '_')
  }

  function Backup-ServerState {
    $serverFile = Join-Path $BackupRoot 'dns_server_state.xml'
    if ($PSCmdlet.ShouldProcess($serverFile, 'Backup DNS server state')) {
      Write-Log "Backing up full DNS server state to $serverFile"
      Get-DnsServer -WarningAction SilentlyContinue | Export-Clixml -Path $serverFile
      $fwdFile = Join-Path $BackupRoot 'dns_global_forwarders_before.xml'
      Get-DnsServerForwarder -WarningAction SilentlyContinue | Export-Clixml -Path $fwdFile
    }
  }

  function Backup-ZoneAnyType {
    param([string]$ZoneName)
    $zone = Get-DnsServerZone -Name $ZoneName -ErrorAction SilentlyContinue
    if (-not $zone) { return }

    $safe = Sanitize-ZoneFileName $ZoneName

    # Always capture the zone object itself
    $zoneObjFile = Join-Path $BackupRoot ("zoneobj_{0}.xml" -f $safe)
    if ($PSCmdlet.ShouldProcess($zoneObjFile, "Backup zone object $ZoneName")) {
      Write-Log "Backing up zone object $ZoneName to $zoneObjFile"
      $zone | Export-Clixml -Path $zoneObjFile
    }

    switch ($zone.ZoneType) {
      'Primary' { 
        $rrFile = Join-Path $BackupRoot ("zone_rr_{0}.xml" -f $safe)
        if ($PSCmdlet.ShouldProcess($rrFile, "Backup records for $ZoneName")) {
          Write-Log "Backing up records for $ZoneName to $rrFile"
          Get-DnsServerResourceRecord -ZoneName $ZoneName | Export-Clixml -Path $rrFile
        }
      }
      'Secondary' { 
        $rrFile = Join-Path $BackupRoot ("zone_rr_{0}.xml" -f $safe)
        if ($PSCmdlet.ShouldProcess($rrFile, "Backup records for $ZoneName")) {
          Write-Log "Backing up records for $ZoneName to $rrFile"
          Get-DnsServerResourceRecord -ZoneName $ZoneName | Export-Clixml -Path $rrFile
        }
      }
      'Stub' {
        $rrFile = Join-Path $BackupRoot ("zone_rr_{0}.xml" -f $safe)
        if ($PSCmdlet.ShouldProcess($rrFile, "Backup records for $ZoneName")) {
          Write-Log "Backing up records for $ZoneName to $rrFile"
          Get-DnsServerResourceRecord -ZoneName $ZoneName | Export-Clixml -Path $rrFile
        }
      }
      'Forwarder' {
        # Conditional forwarders have no RR set. Export their dedicated object if available.
        $cf = $null
        try { $cf = Get-DnsServerConditionalForwarderZone -Name $ZoneName -ErrorAction Stop } catch { $cf = $null }
        if ($cf) {
          $cfFile = Join-Path $BackupRoot ("zone_condfwd_{0}.xml" -f $safe)
          if ($PSCmdlet.ShouldProcess($cfFile, "Backup conditional forwarder $ZoneName")) {
            Write-Log "Backing up conditional forwarder $ZoneName to $cfFile"
            $cf | Export-Clixml -Path $cfFile
          }
        } else {
          Write-Log "No conditional forwarder cmdlet available for $ZoneName. Zone object backup will have to suffice." 'Warn'
        }
      }
      default {
        # Other types, nothing extra beyond the zone object
      }
    }
  }

  function Remove-ExistingZoneIfAny {
    param([string]$ZoneName)
    $zone = Get-DnsServerZone -Name $ZoneName -ErrorAction SilentlyContinue
    if (-not $zone) { Write-Log "Zone $ZoneName not present. Nothing to remove."; return }
    $type = $zone.ZoneType
    if ($PSCmdlet.ShouldProcess($ZoneName, "Remove $type")) {
      Write-Log "Removing $type $ZoneName"
      try {
        if ($type -eq 'Forwarder' -and (Get-Command Remove-DnsServerConditionalForwarderZone -ErrorAction SilentlyContinue)) {
          Remove-DnsServerConditionalForwarderZone -Name $ZoneName -Force
        } else {
          Remove-DnsServerZone -Name $ZoneName -Force
        }
      } catch {
        Write-Log "PowerShell removal failed. Falling back to dnscmd for $ZoneName" 'Warn'
        $null = & dnscmd.exe $env:COMPUTERNAME /zonedelete $ZoneName /f
      }
    }
  }

  function New-SecondaryZone {
    param([string]$ZoneName, [string[]]$Masters)
    $zoneFile = (Sanitize-ZoneFileName -ZoneName $ZoneName) + '.dns'
    if ($PSCmdlet.ShouldProcess($ZoneName, "Create secondary zone from $($Masters -join ', ')")) {
      Write-Log "Creating secondary zone $ZoneName with masters $($Masters -join ', ')"
      Add-DnsServerSecondaryZone -Name $ZoneName -ZoneFile $zoneFile -MasterServers $Masters | Out-Null
    }
  }

  function New-ConditionalForwarderLocal {
    param([string]$ZoneName, [string[]]$Masters)
    if ($PSCmdlet.ShouldProcess($ZoneName, "Create local conditional forwarder to $($Masters -join ', ')")) {
      Write-Log "Creating LOCAL conditional forwarder $ZoneName to $($Masters -join ', ')"
      Add-DnsServerConditionalForwarderZone -Name $ZoneName -MasterServers $Masters | Out-Null
    }
  }

  function Replace-GlobalForwarders {
    param([string[]]$Targets)
    if ($PSCmdlet.ShouldProcess('Global forwarders', "Replace with $($Targets -join ', ')")) {
      Write-Log "Replacing global forwarders with $($Targets -join ', ')"
      Set-DnsServerForwarder -IPAddress $Targets -UseRootHint $false | Out-Null
      $afterFile = Join-Path $BackupRoot 'dns_global_forwarders_after.xml'
      Get-DnsServerForwarder | Export-Clixml -Path $afterFile
    }
  }
}

process {
  Write-Log "Starting DNS cutover. CSV: $CsvPath"
  Backup-ServerState

  $rows = Import-Csv -Path $CsvPath
  foreach ($required in @('type','zone','addresses')) {
    if (-not ($rows | Get-Member -Name $required -MemberType NoteProperty)) {
      throw "CSV must contain columns: type, zone, addresses."
    }
  }

  $normalized = foreach ($r in $rows) {
    [pscustomobject]@{
      type      = ($r.type      -as [string]).Trim().ToLowerInvariant()
      zone      = ($r.zone      -as [string]).Trim()
      addresses = ($r.addresses -as [string])
    }
  }

  $badTypes = $normalized | Where-Object { $_.type -and $_.type -notin @('global','secondary','forwarder') }
  if ($badTypes) {
    $distinct = ($badTypes.type | Select-Object -Unique) -join ', '
    throw "Unsupported 'type' values in CSV: $distinct. Supported: global, secondary, forwarder."
  }

  # Back up all zones we are going to touch, regardless of type
  $zoneRows = $normalized | Where-Object { $_.type -in @('secondary','forwarder') }
  foreach ($row in $zoneRows) {
    if ([string]::IsNullOrWhiteSpace($row.zone)) { throw "Row with type '$($row.type)' is missing a zone name." }
    $ips = Parse-AddressList $row.addresses
    if ((@($ips)).Count -eq 0) { throw "Row for zone '$($row.zone)' requires at least one IP in 'addresses'." }

    Write-Log "Processing $($row.type) for zone $($row.zone)"
    Backup-ZoneAnyType      -ZoneName $row.zone
    Remove-ExistingZoneIfAny -ZoneName $row.zone

    switch ($row.type) {
      'secondary' { New-SecondaryZone             -ZoneName $row.zone -Masters $ips }
      'forwarder' { New-ConditionalForwarderLocal -ZoneName $row.zone -Masters $ips }
    }
  }

  # Global forwarders always replaced
  $globalRows = $normalized | Where-Object { $_.type -eq 'global' }
  if ($globalRows) {
    $targets = foreach ($g in $globalRows) { Parse-AddressList $g.addresses }
    $targets = @($targets | Where-Object { $_ } | Select-Object -Unique)
    if ((@($targets)).Count -gt 0) { Replace-GlobalForwarders -Targets $targets }
    else { Write-Log "Global row(s) found but no valid IPs. Skipping forwarders replacement." }
  } else {
    Write-Log "No global forwarders row in CSV."
  }

  Write-Log "DNS cutover completed."

  # Move backup folder to the directory where the script was run
  $BackupMoved = $false
  try {
    $currentDir = (Get-Location).Path
    $leaf = Split-Path -Leaf $BackupRoot
    $dest = Join-Path $currentDir $leaf

    if ([IO.Path]::GetFullPath($BackupRoot).TrimEnd('\') -ieq [IO.Path]::GetFullPath($dest).TrimEnd('\')) {
      Write-Log "Backup folder already in the current directory: $dest"
    } else {
      if (Test-Path $dest) {
        $i = 1
        do {
          $dest = Join-Path $currentDir ("{0}_moved{1}" -f $leaf, $i)
          $i++
        } while (Test-Path $dest)
      }
      Write-Log "Moving backup folder to $dest"
      try {
        Move-Item -Path $BackupRoot -Destination $dest -Force
      } catch {
        Write-Log "Move failed. Copying instead, then removing original." 'Warn'
        Copy-Item -Path $BackupRoot -Destination $dest -Recurse -Force
        Remove-Item -Path $BackupRoot -Recurse -Force
      }
            # Update paths to the moved location before printing anything so it logs correctly
      $BackupMoved = $true
      $LogPath = Join-Path $dest (Split-Path -Leaf $LogPath)
      $BackupRoot = $dest
Write-Host "Backup folder moved to: $dest"
    }
  } catch {
    Write-Log "Failed to move backup folder: $($_.Exception.Message)" 'Warn'
  }

  try {
    $targetDir = if ($BackupMoved) { $BackupRoot } else { $BackupRoot }
    $csvDest = Join-Path $targetDir (Split-Path -Leaf $CsvPath)
    Copy-Item -Path $CsvPath -Destination $csvDest -Force
  } catch { Write-Host "WARNING: Failed to copy CSV: $($_.Exception.Message)" }
  Write-Host "Action log: $LogPath"
}
