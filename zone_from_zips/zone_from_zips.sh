#!/usr/bin/env bash
set -euo pipefail

# This script searches through a specified directory for ZIP archives, identifies files inside those archives that have a specific name,
# and extracts them into a subdirectory called `_working` within the given directory. Each extracted file is renamed so that its original name
# is followed by an underscore and the name of the archive it came from, without the archive’s file extension. The script requires the `unzip` 
# command to be available and processes all matching files in the top level of the specified directory.

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <zip_dir> <zone_file_name>" >&2
  exit 1
fi

ZIP_DIR=$1
ZONE_FILE=$2

if [[ ! -d "$ZIP_DIR" ]]; then
  echo "Error: directory not found: $ZIP_DIR" >&2
  exit 2
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "Error: 'unzip' is required but not found in PATH." >&2
  exit 3
fi

WORK_DIR="${ZIP_DIR%/}/_working"
mkdir -p "$WORK_DIR"

shopt -s nullglob
mapfile -d '' archives < <(find "$ZIP_DIR" -maxdepth 1 -type f \( -iname "*.zip" \) -print0)

if (( ${#archives[@]} == 0 )); then
  echo "No .zip/.ZIP files found in: $ZIP_DIR" >&2
  exit 4
fi

found_any=0

for zip_path in "${archives[@]}"; do
  archive_name="$(basename "$zip_path")"
  archive_base="${archive_name%.[Zz][Ii][Pp]}"

  if ! list_out=$(unzip -Z -1 "$zip_path" 2>/dev/null); then
    echo "Warning: could not list contents of '$archive_name' (skipping)." >&2
    continue
  fi

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ "$(basename "$entry")" == "$ZONE_FILE" ]]; then
      dest="${WORK_DIR}/${ZONE_FILE}_${archive_base}"
      if unzip -p "$zip_path" "$entry" > "$dest"; then
        echo "Extracted: $archive_name:$entry -> $(realpath "$dest")"
        found_any=1
      else
        echo "Warning: failed to extract '$entry' from '$archive_name'." >&2
      fi
    fi
  done <<< "$list_out"
done

if [[ $found_any -eq 0 ]]; then
  echo "No entries named '$ZONE_FILE' were found in archives within: $ZIP_DIR" >&2
  exit 5
fi

echo "Done. Files are in: $WORK_DIR"
