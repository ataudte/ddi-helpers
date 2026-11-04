# Variables
$volume = "C:"
$path = "C:\temp"
$mysqlPath = "C:\Program Files\Diamond IP\InControl\mysql\bin"
$user = "incadmin"
$password = "incadmin"
$keepFiles = 1209600 # in seconds
$baseFilename = "ipcontrol" 

# Ensure C:\temp exists
if (-Not (Test-Path -Path $path)) {
    New-Item -Path $path -ItemType Directory
}

# Remove old zip files
$now = Get-Date
Get-ChildItem -Path $path -Filter "$baseFilename*.*" | ForEach-Object {
    if ($now - $_.CreationTime -gt [TimeSpan]::FromSeconds($keepFiles)) {
        Remove-Item -Path $_.FullName -Force
    }
}

# Generate timestamp
$timestamp = Get-Date -Format "yyyyMMddHHmmss"

# Filenames
$filename = "$baseFilename-$timestamp.sql"
$logfile = "$path\$baseFilename-$timestamp.log"
$sqlFilePath = Join-Path -Path $path -ChildPath $filename
$zipFilePath = Join-Path -Path $path -ChildPath "$baseFilename-$timestamp.zip"
$logFilePath = Join-Path -Path $path -ChildPath ("$baseFilename-$timestamp.log")


# Change to MySQL bin directory
Set-Location -Path $mysqlPath

# Construct the mysqldump command
$dumpCommand = ".\mysqldump.exe -u$user -p$password --opt --no-tablespaces incontrol"

# Run the mysqldump command
Invoke-Expression "$dumpCommand > `"$sqlFilePath`" 2> `"$logFilePath`""
"File: $sqlFilePath" | Out-File -FilePath $logFilePath -Append
"Zip:  $zipFilePath" | Out-File -FilePath $logFilePath -Append

# Check if the SQL dump was successful
if ($LASTEXITCODE -ne 0) {
    Write-Host "MySQL dump failed. Check log file $logfile for details."
    Get-Content $logFilePath
    "MySQL dump failed. ($dumpCommand)" | Out-File -FilePath $logFilePath -Append
    exit 1
}

# Compress the file
Compress-Archive -Path $sqlFilePath -DestinationPath $zipFilePath 

# Check if the zip file was created successfully
if (Test-Path -Path $zipFilePath) {
    # Delete the original file
    Remove-Item -Path $sqlFilePath -Force
    Write-Output "File zipped and original file deleted."
    "File zipped and original file deleted." | Out-File -FilePath $logFilePath -Append
} else {
    Write-Output "Failed to create zip file."
    "Failed to create zip file. ($zipFilePath)" | Out-File -FilePath $logFilePath -Append
    exit 1
}

exit 0
