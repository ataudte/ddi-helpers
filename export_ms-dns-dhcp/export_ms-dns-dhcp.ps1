<#
.SYNOPSIS
  Exports DNS and DHCP configuration from a Microsoft Windows Server and packages it into a ZIP archive.

.DESCRIPTION
  Collects:
    - DHCP configuration (netsh + Export-DhcpServer) and DHCP failover config
    - DNS zone inventory, server configuration, named.conf-style output
    - Primary zone files (exported and copied to dbs/)
    - Remote DC zone lists and local-vs-remote zone comparisons
  Archives outputs to MS-DNS-DHCP_<hostname>_<timestamp>.zip using synchronous zipping.
#>

#############
# variables #
#############
$debug             = $true
$timestamp         = "$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$log               = "$(Split-Path -Leaf $MyInvocation.MyCommand.Path).log" -replace '\.ps1\.log$',"_${timestamp}.log"
$scriptFolder      = Split-Path -Parent $MyInvocation.MyCommand.Path
$logPath           = Join-Path $scriptFolder $log
$dnsFolder         = ([Environment]::GetFolderPath("System")) + "\dns"
$outputFolder      = $env:SystemDrive + "\DDI_Output"
$dbFolder          = "$outputFolder\dbs"
$dhcpdConf         = "$outputFolder\${env:COMPUTERNAME}_dhcp"
$enumZones         = "$outputFolder\${env:COMPUTERNAME}_enumzones.txt"
$serverConfig      = "$outputFolder\${env:COMPUTERNAME}_dns-config.xml"
$namedConf         = "$outputFolder\${env:COMPUTERNAME}_named.conf"
$zipFileName       = "$scriptFolder\MS-DNS-DHCP_${env:COMPUTERNAME}_${timestamp}.zip"

#############
# functions #
#############
function Msg($message, $level="") {
    if ($level -eq "") { $logPrefix = "# ----- #" }
    elseif ($level -eq "debug") { $logPrefix = "# DEBUG #" }
    elseif ($level -eq "error") { $logPrefix = "# ERROR #" }
    if ($debug -and $level -eq "debug") {
        Write-Host "$logPrefix $message"
        Add-Content -Path $logPath -Value ("[{0:yyyyMMdd-HHmmss}] : {1} {2}" -f (Get-Date), $logPrefix, $message)
    } elseif (!$debug -and $level -eq "debug") {
        Add-Content -Path $logPath -Value ("[{0:yyyyMMdd-HHmmss}] : {1} {2}" -f (Get-Date), $logPrefix, $message)
    } else {
        Write-Host "$logPrefix $message"
        Add-Content -Path $logPath -Value ("[{0:yyyyMMdd-HHmmss}] : {1} {2}" -f (Get-Date), $logPrefix, $message)
    }
}

function Try-ImportModule($name) {
    if (Get-Module -ListAvailable -Name $name) {
        try { Import-Module $name -ErrorAction Stop; return $true }
        catch { Msg "failed to import module ${name}: $($_.Exception.Message)" error; return $false }
    } else { Msg "module $name not available" debug; return $false }
}

function InitializeFolder ([string]$targetFolder) {
    if (-not (Test-Path $targetFolder)) {
      New-Item -Path $targetFolder -type directory | Out-Null
      Msg "folder $targetFolder created"
    } else {
      Msg "folder $targetFolder exists"
    }
}

function CheckForService ([string]$serviceName) {
    $serviceResult = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($serviceResult) { Msg "$env:COMPUTERNAME running: $serviceName"; $true }
    else { Msg "$serviceName was not found"; $false }
}

function Export-DHCPData {
    if (Get-Command netsh -ErrorAction SilentlyContinue) {
        Msg "command netsh available" debug
        netsh dhcp server dump > "$dhcpdConf.txt" all | Out-Null
        if (-not (Test-Path "$dhcpdConf.txt")) { Msg "can not export $dhcpdConf.txt" error }
        else { Msg "DHCP netsh dump exported to $dhcpdConf.txt" }
    } else { Msg "command netsh not available" error }

    if (Get-Command Export-DhcpServer -ErrorAction SilentlyContinue) {
        Msg "command Export-DhcpServer available" debug
        Export-DhcpServer -ComputerName $env:COMPUTERNAME -File "$dhcpdConf.xml" -Leases -Force
        if (-not (Test-Path "$dhcpdConf.xml")) { Msg "can not export $dhcpdConf.xml" error }
        else { Msg "DHCP cmdlet export exported to $dhcpdConf.xml" }
    } else { Msg "command Export-DhcpServer not available" error }
}

function Export-DHCPFailoverConfig {
    try {
        $failoverConfig = Get-DhcpServerv4Failover -ErrorAction Stop
        if ($failoverConfig) {
            $filePath = "${dhcpdConf}_failover.txt"
            $failoverConfig | Format-List * | Out-File -FilePath $filePath -Encoding UTF8
            if (Test-Path $filePath) { Msg "DHCP failover configuration exported to $filePath" }
            else { Msg "Could not write DHCP failover configuration to $filePath" error }
        } else {
            Msg "No DHCP failover configuration found" debug
        }
    } catch {
        Msg "Failed to retrieve DHCP failover configuration: $($_.Exception.Message)" error
    }
}

function Export-DNSData {
    if (-not (Get-Command Get-DnsServerZone -ErrorAction SilentlyContinue)) {
        Msg "DNS cmdlets not available. Skipping DNS export." error
        return
    }

    # 1) Enumerate zones (logic from DNS-OK)
    # Exclude auto-created reverse zones and the DNSSEC TrustAnchors zone
    $allZones       = Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' }
    $primaryZones   = $allZones | Where-Object { $_.ZoneType -eq 'Primary' }
    $secondaryZones = $allZones | Where-Object { $_.ZoneType -eq 'Secondary' }
    $forwarderZones = $allZones | Where-Object { $_.ZoneType -eq 'Forwarder' }

    # 2) Export CSV inventory of zones
    $allZones | Select-Object ZoneName, ZoneType, IsDsIntegrated, IsReverseLookupZone, IsSigned | Export-Csv -Path "$enumZones" -NoTypeInformation
    if (-not (Test-Path "$enumZones")) { Msg "can not export list of hosted zones to $enumZones" error }
    else { Msg "list of hosted zones exported to $enumZones" }

    # 3) Export DNS server configuration
    if (Get-Command Export-Clixml -ErrorAction SilentlyContinue) {
        Get-DnsServer | Export-Clixml -Path "$serverConfig"
        if (-not (Test-Path "$serverConfig")) { Msg "can not export DNS configuration to $serverConfig" error }
        else { Msg "DNS server configuration exported to $serverConfig" }
    } else { Msg "Export-Clixml not available" error }

    # 4) Build named.conf-style output (global forwarders + per-zone stanzas)
    $globalForwarders = Get-DnsServerForwarder -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress
    $namedContent = ""
    if ($globalForwarders -and $globalForwarders.Count -gt 0) {
        $namedContent += "options { forwarders { $($globalForwarders -join '; '); }; };" + [Environment]::NewLine
    }

    foreach ($primaryZone in $primaryZones) {
        $namedContent += "zone `"$($primaryZone.ZoneName)`" IN {" + [Environment]::NewLine
        $namedContent += "  type master;" + [Environment]::NewLine
        $namedContent += "  file `"db.$($primaryZone.ZoneName)`";" + [Environment]::NewLine
        $namedContent += "};" + [Environment]::NewLine
    }

    foreach ($secondaryZone in $secondaryZones) {
        $masters = ($secondaryZone.MasterServers -join '; ')
        $namedContent += "zone `"$($secondaryZone.ZoneName)`" IN {" + [Environment]::NewLine
        $namedContent += "  type slave;" + [Environment]::NewLine
        if ($masters) { $namedContent += "  masters { $masters; };" + [Environment]::NewLine }
        $namedContent += "  file `"db.$($secondaryZone.ZoneName)`";" + [Environment]::NewLine
        $namedContent += "};" + [Environment]::NewLine
    }

    foreach ($forwarderZone in $forwarderZones) {
        $fw = ($forwarderZone.MasterServers -join '; ')
        $namedContent += "zone `"$($forwarderZone.ZoneName)`" IN {" + [Environment]::NewLine
        $namedContent += "  type forward;" + [Environment]::NewLine
        if ($fw) { $namedContent += "  forwarders { $fw; };" + [Environment]::NewLine }
        $namedContent += "};" + [Environment]::NewLine
    }

    Set-Content -Path $namedConf -Value $namedContent -Force
    if (Test-Path "$namedConf") { Msg "DNS configuration located at $namedConf" }
    else { Msg "can not generate named.conf-style output to $namedConf" error }

    # 5) Export zone files for primary zones and collect into dbs/
    foreach ($primaryZone in $primaryZones) {
        try {
            # Export-DnsServerZone writes to %systemroot%\system32\dns
            Export-DnsServerZone -Name $($primaryZone.ZoneName) -FileName db.$($primaryZone.ZoneName).$timestamp -ErrorAction Stop
            $src = Join-Path $dnsFolder ("db." + $primaryZone.ZoneName + ".$timestamp")
            $dst = Join-Path $dbFolder ("db." + $primaryZone.ZoneName)
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $dst -Force
                if (Test-Path $dst) { Msg "zone file db.$($primaryZone.ZoneName) copied to $dbFolder" }
                else { Msg "zone file db.$($primaryZone.ZoneName) could not be copied to $dbFolder" error }
                try { Remove-Item -Path $src -Force -ErrorAction SilentlyContinue } catch {}
            } else {
                Msg "zone file db.$($primaryZone.ZoneName) not present in $dnsFolder after export" error
            }
                try { Remove-Item -Path $src -Force -ErrorAction SilentlyContinue } catch {}
        } catch {
            Msg "failed to export primary zone $($primaryZone.ZoneName): $($_.Exception.Message)" error
        }
    }
}

###################
# build reservoir #
###################
InitializeFolder ($outputFolder)
InitializeFolder ($dbFolder)
#############################################
# find domain controllers in current domain #
#############################################
$adAvailable = Try-ImportModule 'ActiveDirectory'

if ($adAvailable) {
    try {
        $domainName = (Get-ADDomain).DNSRoot
        $domainControllers = Get-ADDomainController -Filter *
    } catch {
        Msg "Active Directory not reachable: $($_.Exception.Message). Continuing without AD." error
        $adAvailable = $false
    }
}

if (-not $adAvailable) {
    $domainName = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().DomainName
    if ([string]::IsNullOrWhiteSpace($domainName)) { $domainName = 'workgroup' }
    $domainControllers = @()
}

$dcList = "$outputFolder\dcList_$domainName.txt"
$domainControllers | Out-File -FilePath "$dcList"
if (-not (Test-Path "$dcList")) { Msg "can not generate list of domain controllers $dcList" error }
else { Msg "list of domain controllers written to $dcList" }
$dcArray = @($domainControllers | Select-Object -ExpandProperty Name)
$dcCount = $dcArray.Count
Msg "$dcCount domain controllers found in current domain"
$c = 1
foreach ($dc in $dcArray) {  Msg "$dc ($c)"; $c++ }

######################################
# check service existence and export #
######################################
$dnsExists  = CheckForService "DNS"
$dhcpExists = CheckForService "DHCPServer"
if ($dhcpExists) { 
    Export-DHCPData
    Export-DHCPFailoverConfig
}
if ($dnsExists)  { Export-DNSData }

#########################################
# compare domain controllers with others #
#########################################
if ($dnsExists -and (Get-Command Get-DnsServerZone -ErrorAction SilentlyContinue)) {
    $localZones = Get-DnsServerZone | Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' }
    $remoteDCs = $dcArray | Where-Object { $_ -ne "$env:COMPUTERNAME" }
    foreach ($remoteDC in $remoteDCs) {
        if (-not (Test-Connection -ComputerName $remoteDC -Count 1 -Quiet)) {
            Msg "cannot connect to $remoteDC" error
            continue
        }
        try {
            Get-DnsServerZone -ComputerName $remoteDC -ErrorAction Stop | Out-Null
            Msg "successfully tested access to $remoteDC" debug

            $remoteEnumZones = "$outputFolder\${remoteDC}_enumzones.txt"
            Get-DnsServerZone -ComputerName $remoteDC |
                Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' } | Select-Object ZoneName, ZoneType, IsDsIntegrated, IsReverseLookupZone, IsSigned |
                Export-Csv -Path "$remoteEnumZones" -NoTypeInformation

            if (-not (Test-Path "$remoteEnumZones")) {
                Msg "can not export list of hosted zones from $remoteDC to $remoteEnumZones" error
            } else {
                Msg "list of hosted zones exported to from $remoteDC to $remoteEnumZones"
            }

            $remoteZones = Get-DnsServerZone -ComputerName $remoteDC | Where-Object { -not $_.IsAutoCreated -and $_.ZoneName -ne 'TrustAnchors' }
            $missingZones    = Compare-Object -ReferenceObject ($localZones | Select-Object -ExpandProperty ZoneName)  -DifferenceObject ($remoteZones | Select-Object -ExpandProperty ZoneName) | Where-Object SideIndicator -eq '<=' | Select-Object -ExpandProperty InputObject
            $additionalZones = Compare-Object -ReferenceObject ($localZones | Select-Object -ExpandProperty ZoneName)  -DifferenceObject ($remoteZones | Select-Object -ExpandProperty ZoneName) | Where-Object SideIndicator -eq '=>' | Select-Object -ExpandProperty InputObject

            if ($missingZones) {
                foreach ($z in $missingZones) { Msg "$remoteDC missing zone: $z" }
                $missingZones | Out-File -FilePath "$outputFolder\${remoteDC}_missing-zones.txt"
            } else {
                Msg "no missing zones on $remoteDC"
            }

            if ($additionalZones) {
                foreach ($z in $additionalZones) { Msg "$remoteDC additional zone: $z" }
                $additionalZones | Out-File -FilePath "$outputFolder\${remoteDC}_additional-zones.txt"
            } else {
                Msg "no additional zones on $remoteDC"
            }
        } catch {
            Msg "Failed to access DNS server on ${remoteDC}: $($_.Exception.Message)" error
        }
    }
} else {
    Msg "DNS cmdlets not available or DNS service absent. Skipping zone comparison." debug
}

###############################
# archive output and clean-up #
###############################
Copy-Item -Path $logPath -Destination "$outputFolder\$log" -Force

# ensure dbs appears in the archive even when empty
if (-not (Get-ChildItem $dbFolder -File -ErrorAction SilentlyContinue)) {
    Set-Content -Path (Join-Path $dbFolder ".placeholder") -Value ""
}

if (Test-Path $zipFileName) { Remove-Item $zipFileName -Force }

if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
    Compress-Archive -Path "$outputFolder\*" -DestinationPath $zipFileName -CompressionLevel Optimal -Force
} else {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($outputFolder, $zipFileName,
        [System.IO.Compression.CompressionLevel]::Optimal, $false)
}

if (Test-Path $zipFileName) {
    Remove-Item $outputFolder -Force -Recurse
    Msg "export located at $zipFileName"
} else {
    Msg "zip creation failed; leaving working folder at $outputFolder for inspection" error
}

#######
# EOF #
#######