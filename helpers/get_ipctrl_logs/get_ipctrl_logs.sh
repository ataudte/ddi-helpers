#!/bin/bash

# Define the log directory
INCHOME="/opt/incontrol"

# Get the current hostname
HOSTNAME=$(hostname)

# Get the current timestamp in the format "yyyymmdd-hhmmss"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")

# Check if the log directory exists
if [ ! -d "$INCHOME" ]; then
    echo "IPControl directory '$INCHOME' does not exist."
    exit 1
fi

# Check if there are log files to process
if ! find "$INCHOME" -type f -name "*.log*" -follow 2>/dev/null | read; then
    echo "No log files found in '$INCHOME'."
    exit 1
fi

# Create a tarball of logs with hostname and timestamp
TARBALL_NAME="/tmp/logs_${HOSTNAME}_${TIMESTAMP}.tar"
find "$INCHOME" -type f -name "*.log*" -follow 2>/dev/null | xargs tar cvf "$TARBALL_NAME"

# Verify the tarball
if tar tvf "$TARBALL_NAME" >/dev/null 2>&1; then
    echo "Tarball '$TARBALL_NAME' looks good."
else
    echo "Error: Tarball '$TARBALL_NAME' not valid."
    exit 1
fi

# Compress the tarball
gzip -vf9 "$TARBALL_NAME"

# List the file size of the compressed tarball
ls -sh "${TARBALL_NAME}.gz"
