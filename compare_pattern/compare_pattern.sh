#!/usr/bin/env bash

# This script compares two files by extracting all lines that contain a given search pattern, 
# normalizing the matches by removing leading and trailing whitespace, and then generating 
# multiple result files showing raw matches, unique matches, common lines, and differences 
# in both unified and side-by-side formats.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 \"pattern\" file1 file2" >&2
  exit 1
fi

pattern="$1"
file1="$2"
file2="$3"

for f in "$file1" "$file2"; do
  if [ ! -f "$f" ]; then
    echo "Error: '$f' is not a file" >&2
    exit 2
  fi
done

sanitize() {
  printf '%s' "$1" | sed -E 's/[^A-Za-z0-9._]+/_/g; s/^_+//; s/_+$//'
}

pat_safe="$(sanitize "$pattern")"
[ -n "$pat_safe" ] || pat_safe="pattern"
b1_safe="$(sanitize "$(basename "$file1")")"
b2_safe="$(sanitize "$(basename "$file2")")"

matches1="${pat_safe}_matches_${b1_safe}.txt"
matches2="${pat_safe}_matches_${b2_safe}.txt"
uniq1="${pat_safe}_unique_${b1_safe}.txt"
uniq2="${pat_safe}_unique_${b2_safe}.txt"
only1="${pat_safe}_only_in_${b1_safe}.txt"
only2="${pat_safe}_only_in_${b2_safe}.txt"
common="${pat_safe}_common.txt"
diff_uni="${pat_safe}_diff_unified.txt"
diff_side="${pat_safe}_diff_side_by_side.txt"

# literal search + normalization: strip leading and trailing whitespace
awk -v pat="$pattern" '
  index($0, pat) {
    s = $0
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    print s
  }
' "$file1" > "$matches1" || true

awk -v pat="$pattern" '
  index($0, pat) {
    s = $0
    sub(/^[[:space:]]+/, "", s)
    sub(/[[:space:]]+$/, "", s)
    print s
  }
' "$file2" > "$matches2" || true

# set operations over normalized text
LC_ALL=C sort -u "$matches1" > "$uniq1"
LC_ALL=C sort -u "$matches2" > "$uniq2"

comm -23 "$uniq1" "$uniq2" > "$only1" || true
comm -13 "$uniq1" "$uniq2" > "$only2" || true
comm -12 "$uniq1" "$uniq2" > "$common"  || true

# diffs over normalized text
diff -u "$matches1" "$matches2" > "$diff_uni" || true
diff -y "$matches1" "$matches2" > "$diff_side" || true

cat <<EOF
Generated:
  $matches1
  $matches2
  $uniq1
  $uniq2
  $only1
  $only2
  $common
  $diff_uni
  $diff_side
EOF
