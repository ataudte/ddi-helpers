param(
    [string]$LogFolder = 'C:\dns_debug',
    [int]$TailLines = 20
)

function Convert-DnsDebugName {
    param([string]$EncodedName)

    $matches = [regex]::Matches($EncodedName, '\((\d+)\)([^()]+)')
    if ($matches.Count -eq 0) { return $EncodedName }

    ($matches | ForEach-Object { $_.Groups[2].Value }) -join '.'
}

function Parse-DnsPacketHeader {
    param([string]$Line)

    if ($Line -notmatch '^(?<Date>\d{2}\.\d{2}\.\d{4})\s+(?<Time>\d{2}:\d{2}:\d{2}).*?\b(?<Proto>UDP|TCP)\b\s+(?<Dir>Rcv|Snd)\s+(?<IP>\d{1,3}(?:\.\d{1,3}){3})\s+\S+\s+\S+\s+\[(.*?)\]\s+(?<Type>[A-Z]+)\s+(?<Name>.+)$') {
        return $null
    }

    [pscustomobject]@{
        Timestamp = "$($matches.Date) $($matches.Time)"
        Direction = $matches.Dir
        ClientIP  = $matches.IP
        QType     = $matches.Type
        QName     = Convert-DnsDebugName $matches.Name.Trim()
    }
}

if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $LogFolder "dns-debug_$stamp.log"

Write-Host "Using log file: $logPath"
Write-Host "Press Ctrl+C to stop viewing."
Write-Host ""

Set-DnsServerDiagnostics `
    -EnableLoggingToFile $true `
    -LogFilePath $logPath `
    -EnableLogFileRollover $false `
    -MaxMBFileSize 500 `
    -Queries $true `
    -QuestionTransactions $true `
    -ReceivePackets $true `
    -SendPackets $true `
    -UdpPackets $true `
    -TcpPackets $true `
    -FullPackets $true `
    -Answers $false `
    -Notifications $false `
    -Update $false `
    -WriteThrough $true

while (-not (Test-Path $logPath)) {
    Start-Sleep -Milliseconds 200
}

$buffer = New-Object System.Collections.Generic.List[string]

Get-Content -Path $logPath -Tail 0 -Wait | ForEach-Object {
    $parsed = Parse-DnsPacketHeader -Line $_

    if ($null -eq $parsed) {
        return
    }

    if ($parsed.Direction -ne 'Rcv') {
        return
    }

    if ($parsed.ClientIP -eq '127.0.0.1') {
        return
    }

    $line = "{0}  {1,-15}  {2,-5}  {3}" -f $parsed.Timestamp, $parsed.ClientIP, $parsed.QType, $parsed.QName

    $buffer.Add($line)
    if ($buffer.Count -gt $TailLines) {
        $buffer.RemoveAt(0)
    }

    Clear-Host
    Write-Host "Watching: $logPath"
    Write-Host "Last $TailLines received queries"
    Write-Host ""

    $buffer | ForEach-Object { Write-Host $_ }
}