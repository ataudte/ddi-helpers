#!/bin/bash

# This script extracts ZIP archives in a given folder that match the pattern 'MS-DNS-DHCP_*.zip' (case-insensitive),
# and places each archive's contents into a dedicated subfolder within an 'exports' directory.
# It reports whether a 'dbs/' folder (typically containing zone files) is present in each extracted archive.

# Ensure a folder path was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_folder_with_archives>"
    exit 1
fi

# Create the exports folder
EXPORTS_DIR="$1/exports"
mkdir -p "$EXPORTS_DIR"

# Iterate over matching ZIP files (case-insensitive)
for zipfile in "$1"/MS-DNS-DHCP_*.zip "$1"/MS-DNS-DHCP_*.ZIP; do
    [ -e "$zipfile" ] || continue

    # Extract base name (no extension)
    basename=$(basename "$zipfile")
    basename="${basename%.*}"

    # Define output folder inside exports/
    extracted_dir="$EXPORTS_DIR/$basename"
    mkdir -p "$extracted_dir"

    echo "Extracting $basename to $extracted_dir"
    unzip -q "$zipfile" -d "$extracted_dir"

    # Optional diagnostics
    echo "✓ Contents extracted to: $extracted_dir"
    if [ -d "$extracted_dir/dbs" ]; then
        echo "✓ Found dbs/ with zone files:"
        find "$extracted_dir/dbs" -type f
    else
        echo "⚠ Warning: dbs/ folder not found in $basename"
    fi
done
