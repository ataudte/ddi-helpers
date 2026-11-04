#!/bin/bash

# Get the script name without extension and create a log file with timestamp
SCRIPT_NAME=$(basename "$0" .sh)
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
LOG_FILE="${SCRIPT_NAME}_${TIMESTAMP}.log"

# Log function
log() {
    echo "[$(date +"%Y-%m-%d %H:%M:%S")] $1" | tee -a "$LOG_FILE"
}

# Directory for JNL files
DIR="/replicated/jail/named/var/dns-config/dbs/"

# Check if the given directory exists
if [ ! -d "$DIR" ]; then
    log "ERROR: Directory '$DIR' does not exist."
    exit 1
fi

log "Starting script with directory: $DIR"

# Stop named service
log "Stopping named service..."
if PsmClient node set dns-enable=0; then
    log "Named service stopped."
else
    log "ERROR: Failed to stop named service."
    exit 1
fi

# Create backup directory if not exists
BACKUP_DIR="/tmp/jnl-backup/"
mkdir -p "$BACKUP_DIR"
log "Backup directory prepared: $BACKUP_DIR"

# Find and process each JNL file in the given directory
find "$DIR" -type f -name "*.jnl" | while read -r jnl_file; do
    log "Processing JNL file: $jnl_file"

    # Backup the journal file
    if cp "$jnl_file" "$BACKUP_DIR"; then
        log "Backup successful for $jnl_file."
        # Delete the journal file
        if rm "$jnl_file"; then
            log "Journal file deleted: $jnl_file"
        else
            log "ERROR: Failed to delete journal file: $jnl_file"
        fi
    else
        log "ERROR: Backup failed for $jnl_file. Skipping removal."
    fi

done

# Start named service
log "Starting named service..."
if PsmClient node set dns-enable=1; then
    log "Named service started."
else
    log "ERROR: Failed to start named service."
    exit 1
fi

log "Script completed."
exit 0
