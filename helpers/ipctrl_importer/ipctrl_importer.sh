#!/bin/bash

# Check if two arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <bash_script> <csv_file>"
    exit 1
fi

# Start timer
SECONDS=0

# Assign arguments to variables
bash_script=$1 # IPControl CLI command
csv_file=$2    # IPControl import CSV

# Username and password variables
username="incadmin" # IPControl database user
password="incadmin" # IPControl database user password

# Check if both files exist
if [ -f "$bash_script" ] && [ -f "$csv_file" ]; then
    # Extract filename without extension
    filename=$(basename -- "$csv_file")
    extension="${filename##*.}"
    filename="${filename%.*}"

    # Create reject and error file names
    reject_file="${filename}_reject.${extension}"
    error_file="${filename}_error.${extension}"

    # Run the command
    ./"$bash_script" -u "$username" -p "$password" -f "$csv_file" -r "$reject_file" -e "$error_file"
else
    echo "Both files must exist."
    exit 1
fi

# Stop timer
duration=$SECONDS
echo "process took $(($duration / 60)) minutes and $(($duration % 60)) seconds"