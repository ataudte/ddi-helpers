#!/bin/bash

# Function to convert IP to decimal
ip_to_dec() {
    local ip=$1
    local a b c d
    IFS=. read -r a b c d <<< "$ip"
    echo "$(( (a << 24) + (b << 16) + (c << 8) + d ))"
}

# Function to convert decimal to IP
dec_to_ip() {
    local dec=$1
    printf "%d.%d.%d.%d" $(( (dec >> 24) & 255 )) $(( (dec >> 16) & 255 )) $(( (dec >> 8) & 255 )) $(( dec & 255 ))
}

# Calculate the number of addresses in a subnet
subnet_size() {
    local mask=$1
    echo $(( 1 << (32 - mask) ))
}

# Ensure the IP address is in full quad-dotted format
format_ip() {
    local ip=$1
    IFS='.' read -r a b c d <<< "$ip"
    printf "%d.%d.%d.%d" ${a:-0} ${b:-0} ${c:-0} ${d:-0}
}

# Check for correct number of arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <network in CIDR format> <subnet mask size>"
    exit 1
fi

# Parse the network and mask
IFS='/' read -r base_ip cidr <<< "$1"
subnet_mask=$2
full_base_ip=$(format_ip "$base_ip") # Ensure IP is in full format

# Use the full IP format for the filename
filename=$(echo "$full_base_ip/$cidr" | sed -e 's/\./-/g' -e 's/\//_/g').csv

# Convert the base IP to decimal
base_dec=$(ip_to_dec "$full_base_ip")

# Calculate the number of addresses per subnet
size=$(subnet_size "$subnet_mask")

# Calculate the number of subnets
num_subnets=$(( 1 << ($subnet_mask - $cidr) ))

echo "Subnet" > "$filename"
for ((i=0; i<num_subnets; i++))
do
    # Calculate subnet's first IP in decimal
    subnet_dec=$(( base_dec + (i * size) ))
    # Convert decimal to IP address
    subnet_ip=$(dec_to_ip "$subnet_dec")
    # Write to CSV
    echo "$subnet_ip/$subnet_mask" >> "$filename"
done

echo "Subnets successfully written to $filename"
