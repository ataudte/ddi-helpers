#!/usr/bin/env bash

# This script sanity-checks a DNS zone file and produce a small report.
# It can inject a missing $ORIGIN and then runs checks, appending results to <zone_file>.report

usage() {
  cat >&2 <<'USAGE'
Usage: check_zone.sh <zone_name> <zone_file>

zone_name   FQDN of the zone (e.g., example.com)
zone_file   Path to the zone file to validate
USAGE
  exit 2
}

# Require exactly two args
if [ "$#" -ne 2 ]; then
  echo "Error: expected 2 arguments, got $#." >&2
  usage
fi

zname="${1-}"
zfile="${2-}"

# Basic sanity on args
if [ -z "$zname" ] || [ -z "$zfile" ]; then
  echo "Error: zone_name and zone_file must not be empty." >&2
  usage
fi

# File checks
if [ ! -e "$zfile" ]; then
  echo "Error: zone file '$zfile' not found." >&2
  exit 3
fi
if [ ! -f "$zfile" ]; then
  echo "Error: '$zfile' exists but is not a regular file." >&2
  exit 3
fi
if [ ! -r "$zfile" ]; then
  echo "Error: zone file '$zfile' is not readable." >&2
  exit 4
fi

set -Eeuo pipefail

zname="$1"
zfile="$2"
report="${zfile}.report"

# Optional: inject $ORIGIN if missing and file looks like a bare SOA/@ start
if ! grep -qi '^\$ORIGIN' "$zfile" && grep -qE '^\s*@\s|IN\s+SOA' "$zfile"; then
  echo "Injecting \$ORIGIN ${zname} into ${zfile##*/}"
  tmpfile="$(mktemp)"
  { printf '$ORIGIN %s.\n' "$zname"; cat "$zfile"; } > "$tmpfile"
  cp -a "$zfile" "${zfile}_$(date '+%Y%m%d-%H%M%S').bak"
  mv "$tmpfile" "$zfile"
fi

run_check() {
  local fmt="$1"
  local tmpout rc
  tmpout="$(mktemp)"

  # Build args in an array (comments allowed on their own lines)
  args=(
    -d          # debug output (optional; remove if too noisy or if it triggers crashes)
    -i full     # full post-load integrity checks
    -k warn     # check-names: warn
    -m warn     # check-mx: warn
    -M warn     # check-mx-cname: warn
    -n warn     # check-ns: warn
    -r warn     # check-srv: warn
    -S warn     # check-srv-cname: warn
    -T warn     # timing/TTL-related checks: warn
    -W warn     # wildcard/other warnings: warn
    -f "$fmt"   # input format: text or raw
  )

  # Run in a subshell; capture stdout+stderr to tmpout so “Abort trap: 6” stays out of the terminal
  if { ( set +e; named-checkzone "${args[@]}" "$zname" "$zfile" ) >"$tmpout" 2>&1; } 2>/dev/null; then
    rc=0
  else
    rc=$?
  fi

  {
    echo "===== $(date +'%Y%m%d-%H%M%S') | named-checkzone format=$fmt exit=$rc ====="
    cat "$tmpout"
    echo
  } >> "$report"

  rm -f "$tmpout"
  return "$rc"
}

# Fresh report header
: > "$report"
{
  echo "Zone: $zname"
  echo "File: $zfile"
  echo
} >> "$report"

run_check text || true
run_check raw || true

echo "Report: $report"
