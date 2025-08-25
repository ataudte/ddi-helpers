#!/bin/bash

# Check if directory and file extension parameters are provided
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <directory> \"<file_suffix>\""
    exit 1
fi

# The directory to process
DIR=$1

# The file extension to look for
SUFFIX=$2
EXTENSION=${SUFFIX#.}

# Check if the directory exists
if [ ! -d "$DIR" ]; then
    echo "Directory does not exist: $DIR"
    exit 1
fi

# Get the basename of the directory
BASENAME=$(basename "$DIR")

# The output file
OUTPUT_FILE="${BASENAME}${SUFFIX}"
if [ -f "$OUTPUT_FILE" ]; then
    echo "Removing existing output file: $OUTPUT_FILE"
    rm "$OUTPUT_FILE"
fi

# Count all files in the directory
TOTAL_FILES=$(find "$DIR" -type f ! -name ".*" | wc -l)

# Count files with the given extension in the directory
TOTAL_EXT_FILES=$(find "$DIR" -type f -name "*${EXTENSION}" | wc -l)

echo "$TOTAL_FILES files in $DIR"
echo "$TOTAL_EXT_FILES ${EXTENSION} files in $DIR"

# Empty the output file if it already exists
> "$OUTPUT_FILE"

# Process each file with the given extension
find "$DIR" -type f -name "*${EXTENSION}" | sort | while IFS= read -r file; do
    cat "$file" >> "$OUTPUT_FILE"
    # Explicitly add a newline character followed by a blank line
    printf "\n\n" >> "$OUTPUT_FILE"
done

echo "Merged ${EXTENSION} files into ${OUTPUT_FILE}"
