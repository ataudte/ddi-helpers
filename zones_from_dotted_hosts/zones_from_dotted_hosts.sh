#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <normalized_zone_file>"
    exit 1
fi

# Store the input file in a variable
zone_file="$1"

# Extract the zone name from the SOA record
zone_name=$(grep -E 'SOA' "$zone_file" | awk '{print $1}')

# Check if the zone name was found
if [ -z "$zone_name" ]; then
    echo "No SOA record found in the zone file."
    exit 1
fi

# Generate temporary files for output in the script's directory
script_dir="$(dirname "$0")"
temp_file_export="$script_dir/temp_01_export.txt"
temp_file_nozone="$script_dir/temp_02_no-zone.txt"
temp_file_cleaned="$script_dir/temp_03_cleaned.txt"
temp_file_unique="$script_dir/temp_04_unique.txt"
result_file="$script_dir/result_file.txt"
subzone_file="$script_dir/subzone_file.txt"

# Extract entries from the first column that end with the specified zone name
grep -E "^[^#]" "$zone_file" | awk -v zone="$zone_name" '$1 ~ zone {print $1}' > "$temp_file_export"

# Check if any entries were found in the first temporary file
if [ -s "$temp_file_export" ]; then
    echo "Entries ending with '$zone_name' written to temporary file: '$temp_file_export'."
    
    # Create a second temporary file with the zone name removed
    awk -v zone="$zone_name" '{gsub(zone, ""); print $0}' "$temp_file_export" > "$temp_file_nozone"

    echo "Entries with zone name removed written to temporary file: '$temp_file_nozone'."
    
    # Create a third temporary file with blank lines and single-column entries removed
    awk 'NF && !($1 ~ /^[^\.]+\.$/) {print $0}' "$temp_file_nozone" > "$temp_file_cleaned"

    echo "Cleaned entries written to temporary file: '$temp_file_cleaned'."
    
    # Generate a sorted unique list from the cleaned temporary file by removing the first label
    awk -F '.' 'NF > 1 { $1=""; sub(/^\.+/, ""); sub(/\.+$/, ""); print $0 }' OFS='.' "$temp_file_cleaned" | sort -u | sed "s/$/.$zone_name/" > "$temp_file_unique"

    echo "Unique entries (first label removed) with zone name added written to temporary file: '$temp_file_unique'."
    
    # Sort the unique entries according to DNS hierarchy and write to the final result file
    awk -F"." 's=""; { for(i=NF;i>0;i--) { if (i<NF) s=s "." $i; else s=$i } ; print s }' "$temp_file_unique" | sort | awk -F"." 's=""; { for(i=NF;i>0;i--) { if (i<NF) s=s "." $i; else s=$i } ; print s }' > "$result_file"

    # Print the contents of the final result file
    echo "Sorted entries written to final result file: '$result_file'."
    echo "Contents of the final result file:"
    cat "$result_file"
    
    # Generate the subzone file with entries containing one label and the zone name
    awk -F'.' 'NF==4 {print}' "$result_file" > "$subzone_file"

    # Check if subzone file is empty and print appropriate message
    if [ -s "$subzone_file" ]; then
        echo "Subzone entries written to: '$subzone_file'."
        echo "Contents of the subzone file:"
        cat "$subzone_file"
    else
        echo "No valid entries found for the subzone file."
        rm "$subzone_file"  # Remove the empty subzone file
    fi
else
    echo "No entries found ending with '$zone_name'."
    rm "$temp_file_export"  # Remove the empty temporary file
fi
# List of temporary files to delete
temp_files=(
           "temp_01_export.txt"
           "temp_02_no-zone.txt"
           "temp_03_cleaned.txt"
           "temp_04_unique.txt"
)

# Cleanup temporary files
for temp_file in "${temp_files[@]}"; do
    if [ -f "$temp_file" ]; then
        rm "$temp_file"
        echo "Deleted temporary file: $temp_file"
    fi
done
