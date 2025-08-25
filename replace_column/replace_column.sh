#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 input_file column_number replacement_value"
    exit 1
fi

# Assign variables from input arguments
input_file="$1"
column_number="$2"
replacement_value="$3"

# Check if the input file exists
if [ ! -f "$input_file" ]; then
    echo "Input file not found!"
    exit 1
fi

# Extract the filename without extension and extension separately
filename="${input_file%.*}"
extension="${input_file##*.}"

# Create the output filename by adding "_new-value" before the extension
output_file="${filename}_${replacement_value}.${extension}"

# Replace the specified column with the given value and save to output file
awk -v col="$column_number" -v val="$replacement_value" 'BEGIN {FS=OFS=","} { $col = val; print }' "$input_file" > "$output_file"

echo "Column $column_number in $input_file replaced with '$replacement_value' and saved to $output_file."
