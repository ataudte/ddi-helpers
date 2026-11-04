#!/usr/bin/env bash

# Filter rows from a data CSV into **match** and **miss** files based on wildcard patterns stored in a values CSV.  
# Supports per-file delimiters, case-insensitive matching by default, and `*` wildcards for prefix, suffix, and substring matches.

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  csv_filter_by_patterns.sh [-s] <data_csv> <data_delimiter> <data_col_idx> <values_csv> <value_delimiter> <values_col_idx>

Positional:
  data_csv          Path to CSV with rows to split into match/miss
  data_delimiter    Delimiter for data_csv (e.g., ',' ';' '|' $'\t')
  data_col_idx      1-based column index in data_csv to compare
  values_csv        Path to CSV with wildcard patterns
  value_delimiter   Delimiter for values_csv (e.g., ',' ';' '|' $'\t')
  values_col_idx    1-based column index in values_csv containing patterns

Options:
  -s                Case-sensitive matching (default: case-insensitive)

Notes:
  - Wildcards in values support '*': prefix (bgp*), suffix (*abc), substring (*def*).
  - If either file's first line lacks the given delimiter, the script exits with a warning.
  - Outputs:
      <datafile>_<valuefile>_match.csv
      <datafile>_<valuefile>_miss.csv
EOF
}

CASE_SENSITIVE=0
while getopts ":sh" opt; do
  case "$opt" in
    s) CASE_SENSITIVE=1 ;;
    h) usage; exit 0 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; usage; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# Expect 6 positional args
if [ "$#" -ne 6 ]; then
  echo "Error: expected 6 positional arguments." >&2
  usage
  exit 2
fi

DATA_CSV="$1"
DATA_DELIM_RAW="$2"
DATA_COL="$3"
VALUES_CSV="$4"
VALUE_DELIM_RAW="$5"
VALUES_COL="$6"

# Convert possible escaped delimiters (e.g., '\t') to literal via printf %b
to_lit() { printf "%b" "$1"; }
DATA_DELIM="$(to_lit "$DATA_DELIM_RAW")"
VALUE_DELIM="$(to_lit "$VALUE_DELIM_RAW")"

# Validate files
for f in "$DATA_CSV" "$VALUES_CSV"; do
  if [ ! -f "$f" ]; then
    echo "Error: file not found: $f" >&2
    exit 1
  fi
done

# Validate numeric cols
if ! [[ "$DATA_COL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: data_col_idx must be a positive integer (got: $DATA_COL)" >&2
  exit 1
fi
if ! [[ "$VALUES_COL" =~ ^[1-9][0-9]*$ ]]; then
  echo "Error: values_col_idx must be a positive integer (got: $VALUES_COL)" >&2
  exit 1
fi

# Quick delimiter presence check on first line (as requested)
first_line() { head -n 1 -- "$1" 2>/dev/null || true; }
DL1="$(first_line "$DATA_CSV")"
DL2="$(first_line "$VALUES_CSV")"

# For grep visibility of tabs/newlines etc., map to printable representation only for messages
printable() {
  # Show tabs as \t, newlines as \n; others as-is
  python3 - <<'PY' "$1" | tr -d '\n'
import sys
s = sys.argv[1]
out = s.replace('\t','\\t').replace('\n','\\n')
print(out)
PY
}
DATA_DELIM_PRINT="$(printable "$DATA_DELIM")"
VALUE_DELIM_PRINT="$(printable "$VALUE_DELIM")"

if ! printf "%s" "$DL1" | grep -q -- "$DATA_DELIM"; then
  echo "Warning: '$DATA_CSV' doesn't appear to use the delimiter '$DATA_DELIM_PRINT' in its first line." >&2
  echo "Please correct the delimiter argument or adjust the CSV file(s). Exiting." >&2
  exit 3
fi
if ! printf "%s" "$DL2" | grep -q -- "$VALUE_DELIM"; then
  echo "Warning: '$VALUES_CSV' doesn't appear to use the delimiter '$VALUE_DELIM_PRINT' in its first line." >&2
  echo "Please correct the delimiter argument or adjust the CSV file(s). Exiting." >&2
  exit 3
fi

# Output paths
DATA_DIR="$(cd "$(dirname "$DATA_CSV")" && pwd)"
DATA_BASE="$(basename "$DATA_CSV")"
VALUES_BASE="$(basename "$VALUES_CSV")"
OUT_MATCH="$DATA_DIR/${DATA_BASE}_${VALUES_BASE}_match.csv"
OUT_MISS="$DATA_DIR/${DATA_BASE}_${VALUES_BASE}_miss.csv"

# Use awk with manual splitting per line so each file can have its own delimiter
awk -v d_delim="$DATA_DELIM" -v v_delim="$VALUE_DELIM" \
    -v DCOL="$DATA_COL" -v VCOL="$VALUES_COL" \
    -v CASE_SENSITIVE="$CASE_SENSITIVE" \
    -v OUT_MATCH="$OUT_MATCH" -v OUT_MISS="$OUT_MISS" '
function trim(s){sub(/^[ \t\r\n]+/,"",s); sub(/[ \t\r\n]+$/,"",s); return s}
function split_by(s, delim, arr,    n){ # simple splitter (no CSV quotes)
  # If delim is regex-significant, escape it for gsub/split
  # Build a charclass if single char; else treat as plain string in split()
  # Use split with 4th arg to keep empties on gawk; for POSIX awk, this is fine for simple cases.
  return split(s, arr, delim)
}
function regex_escape(s){
  gsub(/[][(){}.+?^$|\\]/, "\\\\&", s); return s
}
function wc_to_regex(p,   s){
  s = regex_escape(p)
  gsub(/\*/, ".*", s)
  return "^" s "$"
}

# Load patterns from values file (first file)
FNR==NR {
  n = split_by($0, v_delim, a)
  if (VCOL <= n) {
    raw = trim(a[VCOL])
    if (raw != "") {
      if (!CASE_SENSITIVE) raw = tolower(raw)
      re = wc_to_regex(raw)
      pats[re] = 1
    }
  }
  next
}

# Process data file (second file)
{
  m = split_by($0, d_delim, b)
  if (DCOL > m) {
    print $0 > OUT_MISS
    next
  }
  key = trim(b[DCOL])
  cmp = CASE_SENSITIVE ? key : tolower(key)

  hit = 0
  for (re in pats) {
    if (cmp ~ re) { hit = 1; break }
  }

  if (hit) print $0 > OUT_MATCH
  else     print $0 > OUT_MISS
}
' "$VALUES_CSV" "$DATA_CSV"

echo "Done."
echo "Match file: $OUT_MATCH"
echo "Miss file:  $OUT_MISS"
