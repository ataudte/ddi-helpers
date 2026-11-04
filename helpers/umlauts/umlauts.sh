#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $(basename "$0") '<pattern>' <path>" >&2
  exit 1
fi

pattern=$1
search_path=$2

if [[ ! -d "$search_path" ]]; then
  echo "error: path not found: $search_path" >&2
  exit 2
fi

mapfile -d '' -t files < <(find "$search_path" -type f -iname "$pattern" -print0)

if (( ${#files[@]} == 0 )); then
  echo "no files match '$pattern' under '$search_path'" >&2
  exit 3
fi

for file in "${files[@]}"; do
  echo "repairing and transliterating: $file"
  cp -- "$file" "$file.save"
  tmp=$(mktemp)

  # Step 1: repair double-encoded UTF-8
  iconv -f utf-8 -t latin1 -- "$file" | iconv -f latin1 -t utf-8 -- > "$tmp"
  mv -- "$tmp" "$file"

  # Step 2: transliterate umlauts to ASCII
  sed -i '' 's/ä/ae/g;s/Ä/Ae/g;s/ö/oe/g;s/Ö/Oe/g;s/ü/ue/g;s/Ü/Ue/g;s/ß/ss/g' "$file"
done

echo "done: ${#files[@]} file(s) processed."
