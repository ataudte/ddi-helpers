#!/bin/bash

# This script scans a given directory for ZIP files and checks whether each contains a *_dhcp.xml and/or *_dns-config.xml file.
# It logs the names of ZIP files missing these expected files into 'no-dhcp-xml.csv' and 'no-dns-xml.csv' respectively.
# ZIP files that are unreadable or cannot be processed are listed separately in 'bad-zips.csv'.

# Check if path is given
if [ -z "$1" ]; then
  echo "Usage: $0 <directory_path>"
  exit 1
fi

DIRECTORY="$1"

# Validate the directory exists
if [ ! -d "$DIRECTORY" ]; then
  echo "Error: '$DIRECTORY' is not a valid directory."
  exit 1
fi

# Output files
no_dhcp_file="no-dhcp-xml.csv"
no_dns_file="no-dns-xml.csv"
bad_zip_file="bad-zips.csv"

# Empty output files at start
> "$no_dhcp_file"
> "$no_dns_file"
> "$bad_zip_file"

# Get sorted list of zip files
mapfile -t zip_files < <(find "$DIRECTORY" -maxdepth 1 -type f \( -iname "*.zip" \) | sort)

total=${#zip_files[@]}
count=0

echo "Report for ZIP files in '$DIRECTORY'"
echo "----------------------------------------"
echo "Total ZIP files found: $total"
echo ""

for zipfile in "${zip_files[@]}"; do
  ((count++))
  filename=$(basename "$zipfile")
  echo "[$count/$total] Processing: $filename"

  # Check if the zip file is readable
  if ! unzip -tq "$zipfile" >/dev/null 2>&1; then
    echo "Could not read ZIP file. Skipping content check."
    echo "$filename" >> "$bad_zip_file"
    echo ""
    continue
  fi

  unzip_list=$(unzip -l "$zipfile")

  # Check for *_dhcp.xml
  if echo "$unzip_list" | grep -qE '(^|/)[^/]*_dhcp\.xml'; then
    dhcp_found="yes"
  else
    dhcp_found="no"
    echo "$filename" >> "$no_dhcp_file"
  fi

  # Check for *_dns-config.xml
  if echo "$unzip_list" | grep -qE '(^|/)[^/]*_dns-config\.xml'; then
    dns_found="yes"
  else
    dns_found="no"
    echo "$filename" >> "$no_dns_file"
  fi

  echo "  *_dhcp.xml found:       $dhcp_found"
  echo "  *_dns-config.xml found: $dns_found"
  echo ""
done

echo "Export complete:"
echo " - Missing DHCP XMLs: $no_dhcp_file ($(wc -l < "$no_dhcp_file" | tr -d ' ') entries)"
echo " - Missing DNS XMLs:  $no_dns_file ($(wc -l < "$no_dns_file" | tr -d ' ') entries)"
echo " - Unreadable ZIPs:   $bad_zip_file ($(wc -l < "$bad_zip_file" | tr -d ' ') entries)"


