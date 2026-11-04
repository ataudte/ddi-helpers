#!/bin/bash

# Check if a directory argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 /path/to/directory"
    exit 1
fi

# Use the provided argument as the root directory
root_directory="$1"

# Output file
output_file="named_collection_overview.txt"
sorted_output_file="named_collection_overview_sorted.txt"
unique_output_file="named_collection_overview_unique.txt"
warnings_file="named_collection_overview_warnings.txt"

# Clear output files if they already exist
> "$output_file"
> "$sorted_output_file"
> "$unique_output_file"
> "$warnings_file"

# Function to extract zone info
extract_zone_info() {
    local conf_file="$1"
    local folder_path="$2"
    awk -v folder_path="$folder_path" '
        BEGIN { zone=""; file=""; in_zone_block=0; skip_zone=0 }
        /^[[:space:]]*zone[[:space:]]+/ && !in_zone_block { 
            zone=$0; 
            gsub(/^[[:space:]]*zone[[:space:]]*"|"[[:space:]]*\{|";/, "", zone);
            in_zone_block=1; 
            skip_zone=1; 
            next 
        }
        in_zone_block && /file[[:space:]]+/ { 
            file=$0; 
            gsub(/^[[:space:]]*file[[:space:]]*"|";/, "", file);
            skip_zone=0; 
        }
        in_zone_block && /^[[:space:]]*\};/ {
            if (!skip_zone) {
                print zone "," file "," folder_path 
            }
            in_zone_block=0;
        }
    ' "$conf_file" >> "$output_file"
}

# Find all named.conf files and process each one
find "$root_directory" -name 'named.conf' | while read -r conf_file; do
    folder_path=$(dirname "$conf_file")
    extract_zone_info "$conf_file" "$folder_path"
done

# Function to reverse a domain name
reverse_domain() {
    echo "$1" | awk -F '.' '{ for (i=NF; i>0; i--) printf "%s.", $i; print "" }' | sed 's/.$//'
}

# Sorting the output file by the first column (domain name hierarchy)
while IFS=',' read -r domain file path; do
    reversed_domain=$(reverse_domain "$domain")
    echo "$reversed_domain,$file,$path"
done < "$output_file" | sort | while IFS=',' read -r reversed_domain file path; do
    original_domain=$(reverse_domain "$reversed_domain")
    echo "$original_domain,$file,$path"
done > "$sorted_output_file"

# Create a file with unique zone name and file name combinations, and check for different file names
awk -F "," '
    {
        zone_file_key = $1 ":" $2;
        if (!(zone_file_key in unique_zones)) {
            unique_zones[zone_file_key] = $0;
            count[$1]++;
        }
    }
    END {
        for (key in unique_zones) {
            split(key, zone_file, ":");
            zone = zone_file[1];
            file = zone_file[2];
            if (count[zone] > 1) {
                print "Warning: Zone " zone " has multiple different files." > "'$warnings_file'"
            }
            print unique_zones[key];
        }
    }
' "$sorted_output_file" | \
while IFS=',' read -r domain file path; do
    reversed_domain=$(reverse_domain "$domain")
    echo "$reversed_domain,$file,$path"
done | sort | \
while IFS=',' read -r reversed_domain file path; do
    original_domain=$(reverse_domain "$reversed_domain")
    echo "$original_domain,$file,$path"
done > "$unique_output_file"

# Echo file name and line count
count_lines() {
    local filename=$1

    # Count the number of lines in the file
    local line_count=$(cat $filename | wc -l | awk '{$1=$1};1')

    # Echo the file name and line count without newlines
    echo -n "$filename ($line_count lines)"
}


echo "DNS Zones Overview:        $(count_lines $output_file)"
echo "Sorted Domain Hierarchy:   $(count_lines $sorted_output_file)"
echo "Unique Domain Hierarchy:   $(count_lines $unique_output_file)"
echo "Zones with multiple Files: $(count_lines $warnings_file)"
