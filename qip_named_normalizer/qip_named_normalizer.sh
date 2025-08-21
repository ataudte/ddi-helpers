#!/bin/bash

# This script prepares a QIP-exported BIND/named configuration file for use with named-checkconf.
# It comments out unsupported or environment-specific directives (directory, dnssec-enable, and all qddns blocks),
# then outputs a fully expanded, normalized config using named-checkconf -p.

set -e

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <named.conf>"
  exit 1
fi

INPUT="$1"
BASENAME="${INPUT%.*}"
EXT="${INPUT##*.}"
OUT_TMP="${BASENAME}_filtered.${EXT}"
OUT_NORM="${BASENAME}_normalized.${EXT}"

# Use awk to:
# - Comment 'directory' and 'dnssec-enable' lines (outside of comments)
# - Comment entire 'qddns' blocks (including sub-blocks)
awk '
/^[ \t]*directory[ \t]+/ && $0 !~ /^[ \t]*#/ {print "#" $0; next}
/^[ \t]*dnssec-enable[ \t]+/ && $0 !~ /^[ \t]*#/ {print "#" $0; next}
/^[ \t]*qddns[ \t]*\{/ && $0 !~ /^[ \t]*#/ {
  print "#" $0
  in_qddns=1
  next
}
in_qddns {
  if ($0 ~ /\}/) {
    print "#" $0
    in_qddns=0
  } else {
    print "#" $0
  }
  next
}
{print}
' "$INPUT" > "$OUT_TMP"

# Now run named-checkconf
named-checkconf -p "$OUT_TMP" > "$OUT_NORM"

echo "Normalized config written to: $OUT_NORM"
