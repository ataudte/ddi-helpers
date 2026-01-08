#!/bin/bash

# This script monitors DNS TTL values for a given record at regular intervals.
# It repeatedly queries the configured DNS resolver, extracts the TTL from the response,
# and outputs changes over time to help observe caching behavior and propagation effects.
# Intended for troubleshooting and analysis, not for production monitoring.

set -u

DNS_SERVER=""
RECORD_TYPE=""
FQDN=""
ROOT_MODE=0

# Internal toggle (not a CLI flag):
# 1 = hide DNSSEC-related RR types in TRACE output
# 0 = show everything
HIDE_DNSSEC=1

usage() {
  echo "Usage: $(basename "$0") <FQDN> [-s DNS_SERVER] [-t RECORD_TYPE] [-r]"
}

# manual argv parsing so flags can appear anywhere
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) shift; [[ $# -gt 0 ]] || { usage; exit 1; }; DNS_SERVER="$1" ;;
    -t) shift; [[ $# -gt 0 ]] || { usage; exit 1; }; RECORD_TYPE="$1" ;;
    -r) ROOT_MODE=1 ;;
    -h|--help) usage; exit 0 ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      if [[ -z "$FQDN" ]]; then
        FQDN="$1"
      else
        echo "Unexpected extra argument: $1"
        usage
        exit 1
      fi
      ;;
  esac
  shift
done

[[ -n "$FQDN" ]] || { usage; exit 1; }

# Enforce mutual exclusivity: -r and -s cannot be combined
if (( ROOT_MODE == 1 )) && [[ -n "$DNS_SERVER" ]]; then
  echo "Error: -s cannot be used with -r (root/trace mode)."
  echo "Hint: use -r without -s, or drop -r to query a specific recursive server."
  exit 1
fi

# normalize type for nicer logs (dig accepts either)
if [[ -n "$RECORD_TYPE" ]]; then
  RECORD_TYPE="$(printf '%s' "$RECORD_TYPE" | tr '[:lower:]' '[:upper:]')"
fi

SCRIPT_BASE="$(basename "$0")"
LOG_FILE="${SCRIPT_BASE%.*}.log"

# single try, 1 second timeout
DIG_OPTS=(+tries=1 +time=1)

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

sleep_with_quit() {
  local seconds="$1"
  local i=0 key=""
  while (( i < seconds )); do
    if IFS= read -r -t 1 -n 1 key; then
      [[ "$key" == "Q" || "$key" == "q" ]] && return 1
    fi
    (( i++ ))
  done
  return 0
}

graceful_exit() {
  log "---- Stopping (signal received) ----"
  log "---- Log file: $LOG_FILE ----"
  exit 0
}
trap graceful_exit INT TERM

dig_cmd() {
  if [[ -n "$DNS_SERVER" ]]; then
    dig "${DIG_OPTS[@]}" @"$DNS_SERVER" "$@"
  else
    dig "${DIG_OPTS[@]}" "$@"
  fi
}

log "---- Preparing TTL-based Watch ----"
log "FQDN:        $FQDN"
if (( ROOT_MODE == 1 )); then
  log "Mode:        root mode (+trace)"
else
  [[ -n "$DNS_SERVER" ]] && log "DNS Server:  $DNS_SERVER" || log "DNS Server:  default (system)"
fi
[[ -n "$RECORD_TYPE" ]] && log "Record Type: $RECORD_TYPE" || log "Record Type: default (A)"
log "---- Starting TTL-based Watch ----"

while :; do
  if [[ -n "$RECORD_TYPE" ]]; then
    QTYPE="$RECORD_TYPE"
  else
    QTYPE="A"
  fi

  TTL_MAX=""
  VALUES=""

  if (( ROOT_MODE == 1 )); then
    TRACE_OUT="$(dig "${DIG_OPTS[@]}" +trace "$FQDN" "$QTYPE" 2>&1)"

    log "---- TRACE BEGIN ----"
    printf '%s\n' "$TRACE_OUT" | awk -v hide_dnssec="$HIDE_DNSSEC" '
      function norm(s) {
        sub(/^[ \t]*/, "", s)
        gsub(/^;+[ \t]*/, "", s)   # strip ; or ;; prefix
        return s
      }

      function is_dnssec_type(t) {
        t=toupper(t)
        return (t=="RRSIG" || t=="DS" || t=="DNSKEY" || t=="NSEC" || t=="NSEC3" || t=="NSEC3PARAM" || t=="CDS" || t=="CDNSKEY")
      }

      {
        line = norm($0)

        # hop lines
        if (line ~ /^Received [0-9]+ bytes from /) { print line; next }

        # RR-like lines: name ttl IN TYPE rdata...
        if (line ~ /^[^;].+[ \t][0-9]+[ \t]+IN[ \t]+[A-Za-z0-9]+[ \t]+/) {
          n=split(line, f, /[ \t]+/)
          rrtype = toupper(f[4])
          if (hide_dnssec==1 && is_dnssec_type(rrtype)) next
          print line
          next
        }
      }
    ' | while IFS= read -r line; do log "$line"; done
    log "---- TRACE END ----"

    # TTL + values extraction from trace stream
    PARSED="$(printf '%s\n' "$TRACE_OUT" | awk -v fqdn="$FQDN" -v qtype="$QTYPE" '
      BEGIN {
        qname=fqdn
        if (qname !~ /\.$/) qname=qname "."
        qtype=toupper(qtype)
      }
      function norm(s) {
        sub(/^[ \t]*/, "", s)
        gsub(/^;+[ \t]*/, "", s)
        return s
      }
      {
        line = norm($0)
        if (line ~ /^[^;].+[ \t][0-9]+[ \t]+IN[ \t]+[A-Za-z0-9]+[ \t]+/) {
          n=split(line, f, /[ \t]+/)
          name=f[1]; ttl=f[2]; cls=f[3]; typ=toupper(f[4])
          if (cls != "IN") next
          if (ttl !~ /^[0-9]+$/) next

          key = name SUBSEP typ
          if (!(key in ttlmax) || ttl > ttlmax[key]) ttlmax[key]=ttl

          r=""
          for (i=5; i<=n; i++) r = (r=="" ? f[i] : r " " f[i])
          if (r != "") {
            if (!(key in vals)) vals[key]=r
            else vals[key]=vals[key] "\n" r
          }

          if (name == qname && typ == "CNAME" && n >= 5) cname = f[5]
        }
      }
      END {
        name_use = qname
        key = name_use SUBSEP qtype
        if (!(key in ttlmax) && cname != "") {
          name_use = cname
          key = name_use SUBSEP qtype
        }
        if (!(key in ttlmax)) { print ""; exit }
        print ttlmax[key]
        if (key in vals) print vals[key]
      }
    ')"

    TTL_MAX="$(printf '%s\n' "$PARSED" | sed -n '1p')"
    VALUES="$(printf '%s\n' "$PARSED" | sed -n '2,$p' | awk 'NF>0')"

  else
    ANSWER_OUT="$(dig_cmd +noall +answer "$FQDN" "$QTYPE" 2>&1)"
    TTL_MAX="$(printf '%s\n' "$ANSWER_OUT" | awk '
      NF>=5 && $2 ~ /^[0-9]+$/ { if ($2 > max) max=$2 }
      END { if (max=="") print ""; else print max }
    ')"
    SHORT_OUT="$(dig_cmd +short "$FQDN" "$QTYPE" 2>&1)"
    VALUES="$(printf '%s\n' "$SHORT_OUT" | awk 'NF>0')"
  fi

  if [[ -z "$TTL_MAX" ]]; then
    log "No Answer. Retrying in 5s."
    if ! sleep_with_quit 5; then
      log "---- Stopping (user requested quit) ----"
      log "---- Log file: $LOG_FILE ----"
      exit 0
    fi
    continue
  fi

  [[ -z "$VALUES" ]] && VALUES="(no output)"
  VALUES_ONE_LINE="$(printf '%s\n' "$VALUES" | paste -sd ' ' -)"

  log "TTL=${TTL_MAX} VALUES=${VALUES_ONE_LINE}"

  SLEEP_SECS="$TTL_MAX"
  (( SLEEP_SECS <= 0 )) && SLEEP_SECS=1

  log "---- Sleeping ${SLEEP_SECS}s (press q to quit) ----"
  if ! sleep_with_quit "$SLEEP_SECS"; then
    log "---- Stopping (user requested quit) ----"
    log "---- Log file: $LOG_FILE ----"
    exit 0
  fi
done
