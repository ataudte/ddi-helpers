#!/bin/bash

# This script generates a minimal named.conf file by scanning a directory of DNS zone files.
# For each file, it extracts the zone name from the SOA record and creates a zone definition block.
# The result is written to 'named.conf' in the current directory.

# Check if the directory path is provided and valid
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_zone_files>"
    exit 1
fi

if [ ! -d "$1" ]; then
    echo "Error: Directory $1 does not exist."
    exit 1
fi

ZONE_DIR="$1"
OUTPUT_FILE="named.conf"

# Start the named.conf file
echo "// Generated named.conf" > "$OUTPUT_FILE"

# Process each zone file
for file in "$ZONE_DIR"/*; do
    if [ -f "$file" ]; then
        # Extract the zone name from the SOA record
        ZONE_NAME=$(grep -m 1 'SOA' "$file" | awk '{print $1}')
        if [ -n "$ZONE_NAME" ]; then
            # Remove trailing dot if present
            ZONE_NAME=${ZONE_NAME%.}
            echo "zone \"$ZONE_NAME\" { type master; file \"$file\"; };" >> "$OUTPUT_FILE"
        else
            echo "Warning: No SOA record found in $file"
        fi
    fi
done

echo "named.conf has been generated in $OUTPUT_FILE"
