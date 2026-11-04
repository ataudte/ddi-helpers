#!/usr/bin/env bash
set -o pipefail

# The script discovers the authoritative name servers and compares their
# responses over IPv4 and IPv6, UDP and TCP, with and without EDNS, and with
# different advertised UDP payload sizes. It also checks delegation, SOA and
# NS consistency, TXT response truncation, TCP fallback, DNS Cookies, NSID,
# basic DNSSEC data, and resolution through selected public resolvers.

LC_ALL=C
export LC_ALL

PROGRAM_NAME=$(basename "$0")
SCRIPT_VERSION=1.0.0
ZONE_INPUT=${1:-}
OUTPUT_PARENT=${2:-$PWD}

TIMEOUT=${DNS_DIAG_TIMEOUT:-3}
TRIES=${DNS_DIAG_TRIES:-1}
IPV6_MODE=${DNS_DIAG_IPV6:-auto}       # auto, force, skip
SKIP_TRACE=${DNS_DIAG_SKIP_TRACE:-0}   # 1 skips dig +trace
VERBOSE=${DNS_DIAG_VERBOSE:-0}         # 1 prints raw dig output as well
PUBLIC_RESOLVERS=${DNS_DIAG_PUBLIC_RESOLVERS:-"8.8.8.8 1.1.1.1 9.9.9.9"}

usage() {
  cat <<USAGE
Usage: $PROGRAM_NAME <zone> [output-parent]

Example:
  $PROGRAM_NAME example.com

Optional environment variables:
  DNS_DIAG_TIMEOUT=3
  DNS_DIAG_TRIES=1
  DNS_DIAG_IPV6=auto        # auto, force, skip
  DNS_DIAG_SKIP_TRACE=0     # set to 1 to skip dig +trace
  DNS_DIAG_VERBOSE=0        # set to 1 to print raw dig output
  DNS_DIAG_PUBLIC_RESOLVERS="8.8.8.8 1.1.1.1 9.9.9.9"
USAGE
}

fatal() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

if [ "$ZONE_INPUT" = "-h" ] || [ "$ZONE_INPUT" = "--help" ]; then
  usage
  exit 0
fi

if [ -z "$ZONE_INPUT" ]; then
  usage >&2
  exit 2
fi

case "$ZONE_INPUT" in
  -*|*' '*|*$'\t'*|*$'\r'*|*$'\n'*|*/*)
    fatal "Invalid zone name: $ZONE_INPUT"
    ;;
esac

ZONE=${ZONE_INPUT%.}
[ -n "$ZONE" ] || fatal "The zone name is empty"

case "$TIMEOUT" in
  ''|*[!0-9]*) fatal "DNS_DIAG_TIMEOUT must be a positive integer" ;;
esac
case "$TRIES" in
  ''|*[!0-9]*) fatal "DNS_DIAG_TRIES must be a positive integer" ;;
esac
[ "$TIMEOUT" -gt 0 ] || fatal "DNS_DIAG_TIMEOUT must be greater than zero"
[ "$TRIES" -gt 0 ] || fatal "DNS_DIAG_TRIES must be greater than zero"

case "$IPV6_MODE" in
  auto|force|skip) ;;
  *) fatal "DNS_DIAG_IPV6 must be auto, force, or skip" ;;
esac

DIG_BIN=${DIG_BIN:-$(command -v dig 2>/dev/null || true)}
[ -n "$DIG_BIN" ] || fatal "dig was not found. Install BIND, for example with: brew install bind"

sanitize() {
  # Keep filenames portable and predictable.
  printf '%s' "$1" | tr '/:@ ' '____' | tr -cd 'A-Za-z0-9._-'
}

ZONE_SAFE=$(sanitize "$ZONE")
[ -n "$ZONE_SAFE" ] || ZONE_SAFE=zone
STAMP=$(date -u '+%Y%m%d-%H%M%S')
OUT_DIR="$OUTPUT_PARENT/dns-zone-diag_${ZONE_SAFE}_${STAMP}"
TEST_DIR="$OUT_DIR/tests"
TMP_DIR="$OUT_DIR/.tmp"
FULL_LOG="$OUT_DIR/full.log"
SUMMARY_TSV="$OUT_DIR/summary.tsv"
AUTH_TSV="$OUT_DIR/authoritative-data.tsv"
NS_FILE="$OUT_DIR/nameservers.txt"
ADDR_TSV="$OUT_DIR/nameserver-addresses.tsv"
ENV_FILE="$OUT_DIR/environment.txt"
REPORT_FILE="$OUT_DIR/report.md"
TRACE_FILE="$OUT_DIR/delegation-trace.txt"

mkdir -p "$TEST_DIR" "$TMP_DIR" || fatal "Cannot create output directory: $OUT_DIR"
: > "$FULL_LOG"

cleanup() {
  rm -rf "$TMP_DIR" 2>/dev/null || true
}
trap cleanup EXIT
trap 'printf "\nInterrupted. Partial results remain in: %s\n" "$OUT_DIR" >&2; exit 130' INT TERM

printf 'scope\tnameserver\ttarget\tfamily\ttest\trc\tdns_status\tflags\tanswer_count\ttransport\tmsg_size\tquery_time_ms\tserver_udp\tcookie\tfallback\tresult\tfile\n' > "$SUMMARY_TSV"
printf 'nameserver\taddress\tfamily\tsoa_mname\tsoa_serial\tchild_ns\n' > "$AUTH_TSV"
printf 'nameserver\taddress\tfamily\n' > "$ADDR_TSV"

TEST_COUNTER=0
COOKIE_SUPPORTED=0
NSID_SUPPORTED=0
DIG_HELP=$($DIG_BIN -h 2>&1 || true)
printf '%s\n' "$DIG_HELP" | grep -qi 'cookie' && COOKIE_SUPPORTED=1
printf '%s\n' "$DIG_HELP" | grep -qi 'nsid' && NSID_SUPPORTED=1

NOCOOKIE_ARGS=()
COOKIE_ARGS=()
if [ "$COOKIE_SUPPORTED" -eq 1 ]; then
  NOCOOKIE_ARGS=(+nocookie)
  COOKIE_ARGS=(+cookie)
fi

say() {
  printf '%s\n' "$*"
}

append_log_header() {
  printf '\n================================================================================\n' >> "$FULL_LOG"
  printf '%s\n' "$1" >> "$FULL_LOG"
  printf '================================================================================\n' >> "$FULL_LOG"
}

run_generic() {
  # run_generic <label> <file> <command...>
  local label=$1
  local file=$2
  shift 2
  local rc

  say "[RUN] $label"
  {
    printf 'Label: %s\n' "$label"
    printf 'Command:'
    printf ' %q' "$@"
    printf '\n\n'
  } > "$file"

  "$@" >> "$file" 2>&1
  rc=$?
  printf '\nExit code: %s\n' "$rc" >> "$file"

  append_log_header "$label"
  cat "$file" >> "$FULL_LOG"

  if [ "$VERBOSE" -eq 1 ]; then
    cat "$file"
  fi

  return "$rc"
}

parse_last_status() {
  awk '
    /->>HEADER<<-/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "status:") {
          value = $(i + 1)
          gsub(/,/, "", value)
          status = value
        }
      }
    }
    END { print status }
  ' "$1"
}

parse_last_flags() {
  awk '
    /^;; flags:/ { line = $0 }
    END {
      sub(/^;; flags: /, "", line)
      sub(/;.*/, "", line)
      print line
    }
  ' "$1"
}

parse_last_answer_count() {
  awk '
    /^;; flags:/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "ANSWER:") {
          value = $(i + 1)
          gsub(/,/, "", value)
          answer = value
        }
      }
    }
    END { print answer }
  ' "$1"
}

parse_last_transport() {
  awk '
    /^;; SERVER:/ { line = $0 }
    END {
      if (line ~ /\(TCP\)/) print "TCP"
      else if (line ~ /\(UDP\)/) print "UDP"
    }
  ' "$1"
}

parse_last_msg_size() {
  awk '/^;; MSG SIZE  rcvd:/ { value = $NF } END { print value }' "$1"
}

parse_last_query_time() {
  awk '/^;; Query time:/ { value = $(NF - 1) } END { print value }' "$1"
}

parse_response_udp_size() {
  awk '
    /;; Got answer:/ { got = 1; next }
    got && /EDNS:.*udp:/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "udp:") value = $(i + 1)
      }
    }
    END { print value }
  ' "$1"
}

parse_response_cookie() {
  awk '
    /;; Got answer:/ { got = 1; next }
    got && /; COOKIE:/ { line = $0 }
    END {
      if (line ~ /\(good\)/) print "good"
      else if (line != "") print "present"
      else print "none"
    }
  ' "$1"
}

run_dig() {
  # run_dig <scope> <nameserver> <target> <family> <test> <dig args...>
  local scope=$1
  local nameserver=$2
  local target=$3
  local family=$4
  local test=$5
  shift 5

  TEST_COUNTER=$((TEST_COUNTER + 1))

  local ns_safe test_safe file body rel_file rc
  local status flags answer transport msg_size query_time server_udp cookie fallback result

  ns_safe=$(sanitize "$nameserver")
  test_safe=$(sanitize "$test")
  [ -n "$ns_safe" ] || ns_safe=system
  [ -n "$test_safe" ] || test_safe=test

  file="$TEST_DIR/$(printf '%04d' "$TEST_COUNTER")_${ns_safe}_${family}_${test_safe}.txt"
  body="$TMP_DIR/test-${TEST_COUNTER}.txt"
  rel_file="tests/$(basename "$file")"

  "$DIG_BIN" "$@" > "$body" 2>&1
  rc=$?

  {
    printf 'Scope: %s\n' "$scope"
    printf 'Nameserver: %s\n' "$nameserver"
    printf 'Target: %s\n' "$target"
    printf 'Family: %s\n' "$family"
    printf 'Test: %s\n' "$test"
    printf 'Command:'
    printf ' %q' "$DIG_BIN" "$@"
    printf '\n\n'
    cat "$body"
    printf '\nExit code: %s\n' "$rc"
  } > "$file"

  status=$(parse_last_status "$body")
  flags=$(parse_last_flags "$body")
  answer=$(parse_last_answer_count "$body")
  transport=$(parse_last_transport "$body")
  msg_size=$(parse_last_msg_size "$body")
  query_time=$(parse_last_query_time "$body")
  server_udp=$(parse_response_udp_size "$body")
  cookie=$(parse_response_cookie "$body")

  fallback=no
  grep -q 'Truncated, retrying in TCP mode' "$body" && fallback=yes

  if [ "$rc" -ne 0 ]; then
    if grep -Eqi 'timed out|no servers could be reached|network is unreachable|communications error|connection refused' "$body"; then
      result=NO_RESPONSE
    else
      result=ERROR
    fi
  elif [ -z "$status" ]; then
    result=NO_RESPONSE
  elif [ "$status" != "NOERROR" ]; then
    result=$status
  elif [ "$fallback" = yes ] && [ "$transport" = TCP ]; then
    result=OK_AFTER_TCP
  elif printf ' %s ' "$flags" | grep -q ' tc '; then
    result=TRUNCATED
  else
    result=OK
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$scope" "$nameserver" "$target" "$family" "$test" "$rc" "$status" "$flags" \
    "$answer" "$transport" "$msg_size" "$query_time" "$server_udp" "$cookie" \
    "$fallback" "$result" "$rel_file" >> "$SUMMARY_TSV"

  printf '[%-13s] %-28s %-5s %-32s %s\n' "$result" "$nameserver" "$family" "$test" "${query_time:+${query_time} ms}"

  append_log_header "$scope | $nameserver | $family | $test"
  cat "$file" >> "$FULL_LOG"

  if [ "$VERBOSE" -eq 1 ]; then
    cat "$file"
  fi

  rm -f "$body"
  return 0
}

resolve_records() {
  # resolve_records <type> <name>
  local type=$1
  local name=$2
  local tmp="$TMP_DIR/resolve-${type}-$(sanitize "$name").txt"
  local resolver

  : > "$tmp"
  "$DIG_BIN" +short "$type" "$name" 2>/dev/null >> "$tmp" || true

  if [ ! -s "$tmp" ]; then
    for resolver in $PUBLIC_RESOLVERS; do
      "$DIG_BIN" "@$resolver" +short "$type" "$name" +time="$TIMEOUT" +tries="$TRIES" 2>/dev/null >> "$tmp" || true
    done
  fi

  case "$type" in
    A) awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ { print }' "$tmp" | sort -u ;;
    AAAA) awk '/:/ { print }' "$tmp" | sort -u ;;
    NS) awk 'NF { sub(/\.$/, "", $0); print }' "$tmp" | sort -u ;;
    *) awk 'NF { print }' "$tmp" | sort -u ;;
  esac
}

ipv6_is_available() {
  if [ "$IPV6_MODE" = force ]; then
    return 0
  fi
  if [ "$IPV6_MODE" = skip ]; then
    return 1
  fi

  if command -v route >/dev/null 2>&1; then
    route -n get -inet6 default >/dev/null 2>&1 && return 0
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -rn -f inet6 2>/dev/null | awk '$1 == "default" { found = 1 } END { exit(found ? 0 : 1) }' && return 0
  fi

  return 1
}

collect_authoritative_data() {
  # collect_authoritative_data <ns> <address> <family flag> <family label>
  local ns=$1
  local address=$2
  local family_flag=$3
  local family_label=$4
  local soa_line soa_mname soa_serial child_ns

  soa_line=$($DIG_BIN "$family_flag" "@$address" "$ZONE" SOA +norecurse +short +time="$TIMEOUT" +tries="$TRIES" 2>/dev/null | head -n 1 || true)
  soa_mname=$(printf '%s\n' "$soa_line" | awk '{ print $1 }')
  soa_serial=$(printf '%s\n' "$soa_line" | awk '{ print $3 }')
  child_ns=$($DIG_BIN "$family_flag" "@$address" "$ZONE" NS +norecurse +short +time="$TIMEOUT" +tries="$TRIES" 2>/dev/null \
    | sed 's/\.$//' | sort -u | paste -sd ',' - 2>/dev/null || true)

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$ns" "$address" "$family_label" "$soa_mname" "$soa_serial" "$child_ns" >> "$AUTH_TSV"
}

run_authoritative_matrix() {
  # run_authoritative_matrix <ns> <address> <-4|-6> <IPv4|IPv6>
  local ns=$1
  local address=$2
  local family_flag=$3
  local family_label=$4
  local size

  collect_authoritative_data "$ns" "$address" "$family_flag" "$family_label"

  run_dig authoritative "$ns" "$address" "$family_label" soa_noedns_udp \
    "$family_flag" "@$address" "$ZONE" SOA \
    +norecurse +noedns +ignore +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  run_dig authoritative "$ns" "$address" "$family_label" soa_edns1232_udp \
    "$family_flag" "@$address" "$ZONE" SOA \
    +norecurse +edns=0 +bufsize=1232 "${COOKIE_ARGS[@]}" +ignore +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  if [ "$COOKIE_SUPPORTED" -eq 1 ]; then
    run_dig authoritative "$ns" "$address" "$family_label" soa_edns1232_nocookie_udp \
      "$family_flag" "@$address" "$ZONE" SOA \
      +norecurse +edns=0 +bufsize=1232 +nocookie +ignore \
      +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats
  fi

  run_dig authoritative "$ns" "$address" "$family_label" ns_edns1232_udp \
    "$family_flag" "@$address" "$ZONE" NS \
    +norecurse +edns=0 +bufsize=1232 "${NOCOOKIE_ARGS[@]}" +ignore \
    +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  run_dig authoritative "$ns" "$address" "$family_label" txt_noedns_udp \
    "$family_flag" "@$address" "$ZONE" TXT \
    +norecurse +noedns +ignore +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  for size in 512 1232 1400 4096; do
    run_dig authoritative "$ns" "$address" "$family_label" "txt_edns${size}_nocookie_udp" \
      "$family_flag" "@$address" "$ZONE" TXT \
      +norecurse +edns=0 +bufsize="$size" "${NOCOOKIE_ARGS[@]}" +ignore \
      +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats
  done

  if [ "$COOKIE_SUPPORTED" -eq 1 ]; then
    run_dig authoritative "$ns" "$address" "$family_label" txt_edns1232_cookie_udp \
      "$family_flag" "@$address" "$ZONE" TXT \
      +norecurse +edns=0 +bufsize=1232 +cookie +ignore \
      +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats
  fi

  run_dig authoritative "$ns" "$address" "$family_label" txt_edns1232_auto_fallback \
    "$family_flag" "@$address" "$ZONE" TXT \
    +norecurse +edns=0 +bufsize=1232 "${NOCOOKIE_ARGS[@]}" \
    +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  run_dig authoritative "$ns" "$address" "$family_label" txt_edns1400_auto_fallback \
    "$family_flag" "@$address" "$ZONE" TXT \
    +norecurse +edns=0 +bufsize=1400 "${NOCOOKIE_ARGS[@]}" \
    +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  run_dig authoritative "$ns" "$address" "$family_label" txt_tcp_nocookie \
    "$family_flag" "@$address" "$ZONE" TXT \
    +norecurse +tcp "${NOCOOKIE_ARGS[@]}" \
    +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats

  if [ "$COOKIE_SUPPORTED" -eq 1 ]; then
    run_dig authoritative "$ns" "$address" "$family_label" txt_tcp_cookie \
      "$family_flag" "@$address" "$ZONE" TXT \
      +norecurse +tcp +cookie +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats
  fi

  if [ "$NSID_SUPPORTED" -eq 1 ]; then
    run_dig authoritative "$ns" "$address" "$family_label" txt_tcp_nsid \
      "$family_flag" "@$address" "$ZONE" TXT \
      +norecurse +tcp +nsid "${NOCOOKIE_ARGS[@]}" \
      +time="$TIMEOUT" +tries="$TRIES" +qr +comments +stats
  fi
}

write_environment() {
  {
    printf 'Generated UTC: %s\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf 'Zone: %s\n' "$ZONE"
    printf 'Script: %s\n' "$PROGRAM_NAME"
    printf 'Script version: %s\n' "$SCRIPT_VERSION"
    printf 'dig path: %s\n' "$DIG_BIN"
    printf 'dig version: '
    "$DIG_BIN" -v 2>&1 || true
    printf 'Cookie option detected: %s\n' "$COOKIE_SUPPORTED"
    printf 'NSID option detected: %s\n' "$NSID_SUPPORTED"
    printf 'IPv6 mode: %s\n' "$IPV6_MODE"
    printf 'Timeout: %s\n' "$TIMEOUT"
    printf 'Tries: %s\n' "$TRIES"
    printf '\nSystem:\n'
    uname -a 2>&1 || true
    if command -v sw_vers >/dev/null 2>&1; then
      printf '\nmacOS:\n'
      sw_vers 2>&1 || true
    fi
    if command -v scutil >/dev/null 2>&1; then
      printf '\nSystem DNS configuration:\n'
      scutil --dns 2>&1 || true
    fi
    if command -v route >/dev/null 2>&1; then
      printf '\nIPv4 default route:\n'
      route -n get default 2>&1 || true
      printf '\nIPv6 default route:\n'
      route -n get -inet6 default 2>&1 || true
    fi
  } > "$ENV_FILE"

  append_log_header "Environment"
  cat "$ENV_FILE" >> "$FULL_LOG"
}

write_report() {
  local total_tests failed_tests serial_count serials frag_count
  total_tests=$(awk 'END { print NR - 1 }' "$SUMMARY_TSV")
  failed_tests=$(awk -F '\t' 'NR > 1 && ($16 == "NO_RESPONSE" || $16 == "ERROR" || ($7 != "" && $7 != "NOERROR")) { count++ } END { print count + 0 }' "$SUMMARY_TSV")
  serials=$(awk -F '\t' 'NR > 1 && $5 != "" { print $5 }' "$AUTH_TSV" | sort -u)
  serial_count=$(printf '%s\n' "$serials" | awk 'NF { count++ } END { print count + 0 }')
  frag_count=$(awk -F '\t' '
    NR > 1 && $5 == "txt_edns4096_nocookie_udp" && $10 == "UDP" && $16 == "OK" {
      limit = ($4 == "IPv4" ? 1472 : 1232)
      if (($11 + 0) > limit) count++
    }
    END { print count + 0 }
  ' "$SUMMARY_TSV")

  {
    printf '# DNS zone diagnostics: `%s`\n\n' "$ZONE"
    printf 'Generated: `%s`\n\n' "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    printf 'This report is an automated first pass. The raw results remain authoritative for interpretation.\n\n'

    printf '## Overview\n\n'
    printf '| Item | Result |\n'
    printf '|---|---|\n'
    printf '| Tests executed | %s |\n' "$total_tests"
    printf '| Queries with errors, timeouts, or non NOERROR status | %s |\n' "$failed_tests"
    printf '| Distinct authoritative SOA serials | %s |\n' "$serial_count"
    if [ "${IPV6_AVAILABLE:-0}" -eq 1 ]; then
      printf '| IPv6 authoritative tests | Executed |\n'
    else
      printf '| IPv6 authoritative tests | Skipped, no IPv6 default route detected |\n'
    fi
    printf '| Large untruncated UDP responses with fragmentation exposure | %s |\n' "$frag_count"
    printf '| Full raw log | `%s` |\n' "$(basename "$FULL_LOG")"
    printf '| Machine readable summary | `%s` |\n' "$(basename "$SUMMARY_TSV")"
    printf '\n'

    printf '## Authoritative name servers and addresses\n\n'
    printf '| Name server | Address | Family |\n'
    printf '|---|---|---|\n'
    awk -F '\t' 'NR > 1 { printf "| `%s` | `%s` | %s |\n", $1, $2, $3 }' "$ADDR_TSV"
    printf '\n'

    printf '## Authoritative data consistency\n\n'
    printf '| Name server | Address | Family | SOA MNAME | SOA serial | Child NS RRset |\n'
    printf '|---|---|---|---|---:|---|\n'
    awk -F '\t' 'NR > 1 { printf "| `%s` | `%s` | %s | `%s` | %s | `%s` |\n", $1, $2, $3, $4, $5, $6 }' "$AUTH_TSV"
    printf '\n'

    if [ "$serial_count" -gt 1 ]; then
      printf '> Finding: The authoritative servers returned different SOA serials. Check zone synchronization.\n\n'
    elif [ "$serial_count" -eq 1 ]; then
      printf '> Finding: All reachable authoritative addresses returned the same SOA serial.\n\n'
    else
      printf '> Finding: No SOA serial could be collected. Review reachability and authority.\n\n'
    fi

    printf '## EDNS and transport matrix\n\n'
    printf '| Name server | Address | Family | Test | DNS status | Flags | Answers | Transport | Message bytes | Server UDP | Fallback | Result |\n'
    printf '|---|---|---|---|---|---|---:|---|---:|---:|---|---|\n'
    awk -F '\t' '
      NR > 1 && $1 == "authoritative" && ($5 == "txt_edns1232_nocookie_udp" || $5 == "txt_edns1400_nocookie_udp" || $5 == "txt_edns4096_nocookie_udp" || $5 == "txt_edns1400_auto_fallback" || $5 == "txt_tcp_nocookie") {
        printf "| `%s` | `%s` | %s | `%s` | %s | `%s` | %s | %s | %s | %s | %s | %s |\n", \
          $2, $3, $4, $5, $7, $8, $9, $10, $11, $13, $15, $16
      }
    ' "$SUMMARY_TSV"
    printf '\n'

    printf '## Potential findings\n\n'

    if [ "$failed_tests" -gt 0 ]; then
      printf '### Errors and timeouts\n\n'
      printf '| Name server | Target | Family | Test | Status | Result | Raw file |\n'
      printf '|---|---|---|---|---|---|---|\n'
      awk -F '\t' '
        NR > 1 && ($16 == "NO_RESPONSE" || $16 == "ERROR" || ($7 != "" && $7 != "NOERROR")) {
          printf "| `%s` | `%s` | %s | `%s` | %s | %s | `%s` |\n", $2, $3, $4, $5, $7, $16, $17
        }
      ' "$SUMMARY_TSV"
      printf '\n'
    else
      printf 'No timeout, command error, or non NOERROR DNS status was detected.\n\n'
    fi

    if [ "$frag_count" -gt 0 ]; then
      printf '### UDP fragmentation exposure\n\n'
      printf 'The following 4096 byte EDNS tests returned an untruncated UDP response larger than the conservative path limit. Such responses may be fragmented or dropped on other paths.\n\n'
      printf '| Name server | Address | Family | Message bytes | Raw file |\n'
      printf '|---|---|---|---:|---|\n'
      awk -F '\t' '
        NR > 1 && $5 == "txt_edns4096_nocookie_udp" && $10 == "UDP" && $16 == "OK" {
          limit = ($4 == "IPv4" ? 1472 : 1232)
          if (($11 + 0) > limit) printf "| `%s` | `%s` | %s | %s | `%s` |\n", $2, $3, $4, $11, $17
        }
      ' "$SUMMARY_TSV"
      printf '\n'
    else
      printf 'No untruncated 4096 byte UDP response above the conservative path limit was observed.\n\n'
    fi

    printf '### TCP fallback\n\n'
    printf '| Name server | Address | Family | Test | Fallback seen | Final transport | Result |\n'
    printf '|---|---|---|---|---|---|---|\n'
    awk -F '\t' '
      NR > 1 && $1 == "authoritative" && ($5 == "txt_edns1232_auto_fallback" || $5 == "txt_edns1400_auto_fallback") {
        printf "| `%s` | `%s` | %s | `%s` | %s | %s | %s |\n", $2, $3, $4, $5, $15, $10, $16
      }
    ' "$SUMMARY_TSV"
    printf '\n'

    printf '### DNS Cookies\n\n'
    if [ "$COOKIE_SUPPORTED" -eq 1 ]; then
      printf '| Name server | Address | Family | Test | Response cookie | Result |\n'
      printf '|---|---|---|---|---|---|\n'
      awk -F '\t' '
        NR > 1 && $1 == "authoritative" && ($5 == "txt_edns1232_cookie_udp" || $5 == "txt_tcp_cookie") {
          printf "| `%s` | `%s` | %s | `%s` | %s | %s |\n", $2, $3, $4, $5, $14, $16
        }
      ' "$SUMMARY_TSV"
      printf '\n'
    else
      printf 'The installed dig version did not advertise DNS Cookie options, so Cookie specific tests were skipped.\n\n'
    fi

    printf '## Interpretation notes\n\n'
    printf '* Tests ending in `_udp` use `+ignore`, so a TC response is preserved and dig does not retry over TCP.\n'
    printf '* Tests ending in `_auto_fallback` omit `+ignore`, allowing dig to retry over TCP after TC.\n'
    printf '* Direct TCP tests verify TCP port 53 from this client to the tested authoritative address.\n'
    printf '* Public recursive resolver tests verify the result seen through those resolvers. A TCP query to a public resolver does not prove TCP reachability from that resolver to an authoritative server.\n'
    printf '* Anycast and source dependent behavior can differ from this measurement point. Repeat the script from affected networks when possible.\n'
    printf '* A large TXT RRset can force truncation and TCP even when the SPF record itself is small.\n'
    printf '\n'

    printf '## Files\n\n'
    printf '* `%s`: complete combined log\n' "$(basename "$FULL_LOG")"
    printf '* `%s`: one row per DNS test\n' "$(basename "$SUMMARY_TSV")"
    printf '* `%s`: SOA and child NS consistency data\n' "$(basename "$AUTH_TSV")"
    printf '* `%s`: discovered name server addresses\n' "$(basename "$ADDR_TSV")"
    printf '* `%s`: local system and resolver configuration\n' "$(basename "$ENV_FILE")"
    if [ -f "$TRACE_FILE" ]; then
      printf '* `%s`: iterative delegation trace\n' "$(basename "$TRACE_FILE")"
    fi
    printf '* `tests/`: raw output for every individual query\n'
  } > "$REPORT_FILE"
}

say ""
say "# DNS diagnostics for: $ZONE"
say "# Output directory:    $OUT_DIR"
say ""

write_environment

# Baseline through the local resolver.
run_dig recursive local-system system auto baseline_ns \
  "$ZONE" NS +time="$TIMEOUT" +tries="$TRIES" +comments +stats
run_dig recursive local-system system auto baseline_soa \
  "$ZONE" SOA +time="$TIMEOUT" +tries="$TRIES" +comments +stats
run_dig recursive local-system system auto baseline_txt_edns1232 \
  "$ZONE" TXT +edns=0 +bufsize=1232 "${NOCOOKIE_ARGS[@]}" \
  +time="$TIMEOUT" +tries="$TRIES" +comments +stats
run_dig recursive local-system system auto baseline_txt_tcp \
  "$ZONE" TXT +tcp "${NOCOOKIE_ARGS[@]}" \
  +time="$TIMEOUT" +tries="$TRIES" +comments +stats
run_dig recursive local-system system auto baseline_ds \
  "$ZONE" DS +dnssec +time="$TIMEOUT" +tries="$TRIES" +comments +stats
run_dig recursive local-system system auto baseline_dnskey \
  "$ZONE" DNSKEY +dnssec +time="$TIMEOUT" +tries="$TRIES" +comments +stats

# Delegation trace.
if [ "$SKIP_TRACE" != 1 ]; then
  run_generic "Delegation trace for $ZONE" "$TRACE_FILE" \
    "$DIG_BIN" +trace "$ZONE" NS +time="$TIMEOUT" +tries="$TRIES" || true
fi

# Discover the authoritative name servers.
resolve_records NS "$ZONE" > "$NS_FILE"
if [ ! -s "$NS_FILE" ]; then
  fatal "No authoritative name servers could be discovered. Partial results are in: $OUT_DIR"
fi

say ""
say "# Authoritative name servers:"
sed 's/^/  /' "$NS_FILE"
say ""

IPV6_AVAILABLE=0
if ipv6_is_available; then
  IPV6_AVAILABLE=1
else
  say "IPv6 tests will be skipped because no IPv6 default route was detected."
  say "Set DNS_DIAG_IPV6=force to run them anyway."
  say ""
fi

# Resolve and test every published address for every authoritative name server.
while IFS= read -r ns; do
  [ -n "$ns" ] || continue

  A_FILE="$TMP_DIR/a-$(sanitize "$ns").txt"
  AAAA_FILE="$TMP_DIR/aaaa-$(sanitize "$ns").txt"
  resolve_records A "$ns" > "$A_FILE"
  resolve_records AAAA "$ns" > "$AAAA_FILE"

  if [ ! -s "$A_FILE" ] && [ ! -s "$AAAA_FILE" ]; then
    printf '%s\t\tunknown\n' "$ns" >> "$ADDR_TSV"
    say "[NO ADDRESS] $ns"
    continue
  fi

  while IFS= read -r address; do
    [ -n "$address" ] || continue
    printf '%s\t%s\tIPv4\n' "$ns" "$address" >> "$ADDR_TSV"
    run_authoritative_matrix "$ns" "$address" -4 IPv4
  done < "$A_FILE"

  while IFS= read -r address; do
    [ -n "$address" ] || continue
    printf '%s\t%s\tIPv6\n' "$ns" "$address" >> "$ADDR_TSV"
    if [ "$IPV6_AVAILABLE" -eq 1 ]; then
      run_authoritative_matrix "$ns" "$address" -6 IPv6
    fi
  done < "$AAAA_FILE"
done < "$NS_FILE"

# Compare results through common public recursive resolvers.
for resolver in $PUBLIC_RESOLVERS; do
  run_dig recursive "resolver-$resolver" "$resolver" IPv4 recursive_txt_udp \
    -4 "@$resolver" "$ZONE" TXT +edns=0 +bufsize=1232 "${NOCOOKIE_ARGS[@]}" \
    +time="$TIMEOUT" +tries="$TRIES" +comments +stats

  run_dig recursive "resolver-$resolver" "$resolver" IPv4 recursive_txt_tcp \
    -4 "@$resolver" "$ZONE" TXT +tcp "${NOCOOKIE_ARGS[@]}" \
    +time="$TIMEOUT" +tries="$TRIES" +comments +stats

  if [ "$NSID_SUPPORTED" -eq 1 ]; then
    run_dig recursive "resolver-$resolver" "$resolver" IPv4 recursive_txt_nsid \
      -4 "@$resolver" "$ZONE" TXT +nsid "${NOCOOKIE_ARGS[@]}" \
      +time="$TIMEOUT" +tries="$TRIES" +comments +stats
  fi
done

write_report

say ""
say "# Completed."
say ""
say "# Report:   $REPORT_FILE"
say "# Full log: $FULL_LOG"
say "# Summary:  $SUMMARY_TSV"
say ""
