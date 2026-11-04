#!/bin/bash

# Check if a file parameter is given
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <dhcpd.conf file>"
    exit 1
fi

input_file=$1
base_name=$(basename "$input_file" .conf)
output_file="${base_name}.csv"

# Check if input file exists
if [ ! -f "$input_file" ]; then
    echo "File not found: $input_file"
    exit 1
fi

# Function to convert subnet mask to CIDR notation
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: Invalid subnet mask." >&2; exit 1;;
        esac
    done
    echo "$nbits"
    unset IFS
}

# Create/overwrite the output file
echo "Subnet,Mask,CIDR" > "$output_file"

# Process the file
while IFS= read -r line; do
    if [[ $line =~ ^[[:space:]]*subnet[[:space:]]+([0-9\.]+)[[:space:]]+netmask[[:space:]]+([0-9\.]+) ]]; then
        subnet=${BASH_REMATCH[1]}
        mask=${BASH_REMATCH[2]}
        cidr=$(mask2cidr $mask)
        echo "$subnet,$mask,$cidr" >> "$output_file"
    fi
done < "$input_file"

echo "CSV file created: $output_file"
