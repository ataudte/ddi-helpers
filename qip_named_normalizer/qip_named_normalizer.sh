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
BEGIN { in_qddns=0; qddns_pending=0; depth=0 }

# comment out single-line directives we don’t want
/^[[:space:]]*directory[[:space:]]+"/      { print "#" $0; next }
/^[[:space:]]*dnssec-enable[[:space:]]+/   { print "#" $0; next }

# ---- qddns start (same line with "{", or without it) ----
/^[[:space:]]*qddns([[:space:]]*;)?[[:space:]]*$/ {
  # bare "qddns" on its own line (no "{")
  qddns_pending=1
  print "#" $0
  next
}
/^[[:space:]]*qddns[[:space:]]*\{/ {
  # "qddns {" on the same line
  in_qddns=1
  # count braces without altering the line
  tmp=$0; opens=gsub(/\{/, "", tmp)
  tmp=$0; closes=gsub(/\}/, "", tmp)
  depth = opens - closes
  print "#" $0
  next
}

# ---- line(s) immediately after a bare "qddns" ----
qddns_pending && !in_qddns {
  # comment this line
  print "#" $0
  # start depth tracking once we encounter the first "{"
  tmp=$0; opens=gsub(/\{/, "", tmp)
  tmp=$0; closes=gsub(/\}/, "", tmp)
  if (opens > 0) {
    in_qddns=1
    depth = opens - closes
    qddns_pending=0
    if (depth <= 0) { in_qddns=0; depth=0 }
  }
  next
}

# ---- inside qddns: comment everything (including nested edup {...}) ----
in_qddns {
  tmp=$0; opens=gsub(/\{/, "", tmp)
  tmp=$0; closes=gsub(/\}/, "", tmp)
  depth += opens - closes
  print "#" $0
  if (depth <= 0) { in_qddns=0; depth=0 }
  next
}

# default: pass through
{ print }
' "$INPUT" > "$OUT_TMP"



# Now run named-checkconf
named-checkconf -p "$OUT_TMP" > "$OUT_NORM"

echo "Normalized config written to: $OUT_NORM"
