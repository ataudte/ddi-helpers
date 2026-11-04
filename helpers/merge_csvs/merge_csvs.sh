#!/bin/bash

# This script merges all CSV files in the given directory into one timestamped CSV,
# keeps only the header from the first file, processes files in sorted order,
# ensures clean line breaks, and prints data line counts per file and overall.
# If ssconvert is available, also creates an .xls version of the merged file.

if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

CSV_DIR="$1"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BASENAME="dns_zone_overview_${TIMESTAMP}"
CSV_OUT="${CSV_DIR}/${BASENAME}.csv"
XLS_OUT="${CSV_DIR}/${BASENAME}.xls"
HEADER_WRITTEN=false
TOTAL_LINES=0

echo "Merging CSV files from: $CSV_DIR"
echo "Output will be saved to: $CSV_OUT"
echo

for csv in $(ls "$CSV_DIR"/*.csv | sort); do
  LINES=$(($(wc -l < "$csv") - 1))
  echo "$(basename "$csv"): $LINES data lines"
  TOTAL_LINES=$((TOTAL_LINES + LINES))

  if [ "$HEADER_WRITTEN" = false ]; then
    cat "$csv" >> "$CSV_OUT"
    HEADER_WRITTEN=true
  else
    tail -n +2 "$csv" >> "$CSV_OUT"
  fi
done

MERGED_LINES=$(($(wc -l < "$CSV_OUT") - 1))

echo
echo "Expected total data lines: $TOTAL_LINES"
echo "Actual data lines in merged file: $MERGED_LINES"

# Convert to XLS if ssconvert is available
if command -v ssconvert >/dev/null 2>&1; then
  echo
  echo "ssconvert found. Converting to XLS..."
  ssconvert "$CSV_OUT" "$XLS_OUT"
  echo "XLS file created: $XLS_OUT"
else
  echo
  echo "ssconvert not found. Skipping XLS generation."
fi
