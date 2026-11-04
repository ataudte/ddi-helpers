#!/usr/bin/env bash
#
# Console DNS monitor for macOS (Bash 3.2+).
# Checks NS records, server reachability, and SOA serial consistency.
# Inspired by Carsten's DNS traffic lights:
# https://github.com/cstrotm/DNS-traffic-lights
#
# Usage: ./ns_watch.sh <domain|file> <-d|-f> [interval]
# Default interval: 10 seconds. Quit: q, Q, Esc, or Ctrl+C.

PROG=${0##*/}
DIG_OPTS=(+time=2 +tries=1)

usage() {
  cat >&2 <<EOF
Usage: $PROG <domain|file> <-d|-f> [interval]

  -d, --fqdn    treat the first argument as a single FQDN
  -f, --file    treat the first argument as a text file with one FQDN per line
                (blank lines and # comments are ignored)
  interval      seconds between checks, positive integer (default: 10)

Examples:
  $PROG example.com -d
  $PROG domains.txt -f 5

Press q or Esc to stop monitoring.
EOF
  exit "${1:-1}"
}

die()  { printf '%s: %s\n' "$PROG" "$*" >&2; exit 1; }
warn() { printf '%s: %s\n' "$PROG" "$*" >&2; }

# --- colours ----------------------------------------------------------------
R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; D=$'\033[90m'; B=$'\033[1m'; N=$'\033[0m'

# --- helpers ----------------------------------------------------------------
LABEL_RE='^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$'
NUM_RE='^[0-9]+$'

# RFC 1035/1123 host name syntax: labels of 1-63 chars [A-Za-z0-9-], no leading
# or trailing hyphen, total length <= 253, TLD not all-numeric.
# A bare TLD (single label) is accepted only in absolute form, e.g. "de."
is_valid_fqdn() {
  local fqdn=$1 name label
  local -a labels
  name=${fqdn%.}
  [[ -n $name && ${#name} -le 253 ]]                 || return 1
  [[ $name != .* && $name != *. && $name != *..* ]]  || return 1
  [[ $name == *.* || $fqdn == *. ]]                  || return 1
  IFS=. read -r -a labels <<< "$name"
  for label in "${labels[@]}"; do
    [[ $label =~ $LABEL_RE ]] || return 1
  done
  [[ ! ${labels[${#labels[@]}-1]} =~ $NUM_RE ]]
}

lc()   { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

DOMAINS=()
add_domain() {                       # adds a domain once (deduplicated)
  local d x
  d=$(lc "${1%.}")
  for x in "${DOMAINS[@]}"; do [[ $x == "$d" ]] && return; done
  DOMAINS+=("$d")
}

# --- arguments --------------------------------------------------------------
[[ $1 == -h || $1 == --help ]] && usage 0
[[ $# -eq 2 || $# -eq 3 ]] || usage

TARGET=$1
MODE=$2
INTERVAL=${3:-10}
SKIPPED=0

[[ $INTERVAL =~ $NUM_RE && $INTERVAL -gt 0 ]] || die "interval must be a positive integer: '$INTERVAL'"

case $MODE in
  -d|--fqdn)
    is_valid_fqdn "$TARGET" || die "not a valid FQDN: '$TARGET'"
    add_domain "$TARGET"
    ;;
  -f|--file)
    [[ -e $TARGET ]] || die "file not found: $TARGET"
    [[ -f $TARGET ]] || die "not a regular file: $TARGET"
    [[ -r $TARGET ]] || die "file not readable: $TARGET"
    n=0
    while IFS= read -r line || [[ -n $line ]]; do
      n=$((n + 1))
      line=${line%%#*}
      line=$(trim "${line//$'\r'/}")
      [[ -z $line ]] && continue
      if is_valid_fqdn "$line"; then
        add_domain "$line"
      else
        warn "$TARGET:$n: skipping invalid FQDN '$line'"
        SKIPPED=$((SKIPPED + 1))
      fi
    done < "$TARGET"
    [[ ${#DOMAINS[@]} -gt 0 ]] || die "no valid FQDNs found in $TARGET"
    ;;
  *)
    warn "unknown mode '$MODE' (use -d or -f)"
    usage
    ;;
esac

command -v dig >/dev/null 2>&1 || die "'dig' not found"
[[ -t 0 && -t 1 ]]             || die "must be run in an interactive terminal"

if (( SKIPPED > 0 )); then
  warn "$SKIPPED invalid line(s) skipped - starting in 3s"
  sleep 3
fi

# --- the actual check (runs in the background, one job per zone) -----------
dns_status() { sed -n 's/.*status: \([A-Z]*\).*/\1/p' | head -n 1; }

check_domain() {
  local zone=$1 out=$2
  local resp rc status level lamp sc note ns ip soa st serial rtt err v4 v6 i mism col ok
  local -a nss v4s v6s serials rtts errs

  resp=$(dig "${DIG_OPTS[@]}" +noall +comments +answer NS "$zone" 2>/dev/null); rc=$?
  status=$(dns_status <<< "$resp")
  if [[ -z $status ]]; then
    if (( rc == 9 )); then status=TIMEOUT; else status=ERROR; fi
  fi

  nss=( $(awk '$4 == "NS" { print $5 }' <<< "$resp" | sort -u) )

  for ((i = 0; i < ${#nss[@]}; i++)); do
    ns=${nss[i]}
    v4=$(dig "${DIG_OPTS[@]}" +short A    "$ns" 2>/dev/null | grep -E '^[0-9.]+$' | paste -sd, -)
    v6=$(dig "${DIG_OPTS[@]}" +short AAAA "$ns" 2>/dev/null | grep ':'            | paste -sd, -)
    serial='' rtt='' err=''
    [[ -z $v4$v6 ]] && err="NO ADDRESS"

    for ip in ${v4//,/ } ${v6//,/ }; do          # IPv4 first, then IPv6
      soa=$(dig "${DIG_OPTS[@]}" +norec SOA "$zone" "@$ip" 2>/dev/null); rc=$?
      if (( rc == 9 )); then err=TIMEOUT; continue; fi
      st=$(dns_status <<< "$soa")
      if [[ $st != NOERROR ]]; then err=${st:-ERROR}; continue; fi
      serial=$(awk '$4 == "SOA" { print $7; exit }' <<< "$soa")
      if [[ -z $serial ]]; then err="NO SOA"; continue; fi
      rtt=$(sed -n 's/^;; Query time: \([0-9]*\) msec.*/\1/p' <<< "$soa")
      err=''
      break
    done

    v4s[i]=$v4; v6s[i]=$v6; serials[i]=$serial; rtts[i]=$rtt; errs[i]=$err
  done

  mism=$(printf '%s\n' "${serials[@]}" | grep -v '^$' | sort -u | wc -l)
  ok=0
  for ((i = 0; i < ${#nss[@]}; i++)); do [[ -n ${serials[i]} ]] && ok=$((ok + 1)); done

  # traffic light: worst result of NS lookup and direct SOA queries
  note=''
  case $status in
    NOERROR)
      if (( ${#nss[@]} == 0 )); then
        level=green
      elif (( ok == 0 )); then
        level=red;    note="none of ${#nss[@]} name servers answered"
      elif (( ok < ${#nss[@]} )); then
        level=yellow; note="$ok of ${#nss[@]} name servers answered"
      elif (( mism > 1 )); then
        level=yellow; note="SOA serials differ"
      else
        level=green;  note="$ok of ${#nss[@]} name servers answered"
      fi ;;
    NXDOMAIN) level=yellow ;;
    *)        level=red ;;
  esac
  case $level in
    green)  lamp="${D}●${N} ${D}●${N} ${G}●${N}"; sc=$G ;;
    yellow) lamp="${D}●${N} ${Y}●${N} ${D}●${N}"; sc=$Y ;;
    red)    lamp="${R}●${N} ${D}●${N} ${D}●${N}"; sc=$R ;;
  esac

  {
    printf '%s  %s%-30s%s %s%-9s%s %s%s%s\n' "$lamp" "$B" "$zone" "$N" "$sc" "$status" "$N" "$sc" "$note" "$N"
    if [[ $status == NOERROR && ${#nss[@]} -eq 0 ]]; then
      printf '       %s(no NS records at this name)%s\n' "$D" "$N"
    fi
    for ((i = 0; i < ${#nss[@]}; i++)); do
      if [[ -n ${errs[i]} ]]; then
        col="${R}$(printf '%-12s' "${errs[i]}")${N}"
      else
        if (( mism > 1 )); then col=$R; else col=''; fi
        col="${col}$(printf '%-12s' "${serials[i]}")${N} ${rtts[i]:+${rtts[i]} ms}"
      fi
      printf '       %-30s %-18s %-30s %s\n' "${nss[i]%.}" "${v4s[i]:--}" "${v6s[i]:--}" "$col"
    done
    echo
  } > "$out.tmp"
  mv "$out.tmp" "$out"                           # file exists = job finished
}

# --- terminal handling ------------------------------------------------------
POLL=1
(( BASH_VERSINFO[0] >= 4 )) && POLL=0.2          # bash 3.2 only knows whole seconds

TMPD=$(mktemp -d "${TMPDIR:-/tmp}/dnslights.XXXXXX") || die "cannot create temp dir"
STTY_SAVED=$(stty -g)

cleanup() {
  local pids
  pids=$(jobs -p)
  [[ -n $pids ]] && kill $pids 2>/dev/null
  stty "$STTY_SAVED" 2>/dev/null
  tput cnorm 2>/dev/null
  rm -rf "$TMPD"
  printf '\n'
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

stty -echo
tput civis 2>/dev/null
RESIZED=0
trap 'RESIZED=1' WINCH

status_line() { printf '\r\033[K%s%s%s' "$D" "$*" "$N"; }

quit_pressed() {                                  # waits up to $POLL seconds
  local key
  IFS= read -rsn1 -t "$POLL" key 2>/dev/null || return 1
  [[ $key == q || $key == Q || $key == $'\e' ]]
}

all_done() {
  local i
  for ((i = 0; i < ${#DOMAINS[@]}; i++)); do [[ -e $TMPD/$i ]] || return 1; done
}

header() {
  printf '%sns_watch%s - DNS status   %s   every %ss   %d zone(s)' \
    "$B" "$N" "$(date '+%Y-%m-%d %H:%M:%S')" "$INTERVAL" "${#DOMAINS[@]}"
  (( SKIPPED > 0 )) && printf '   %s%d invalid line(s) skipped%s' "$Y" "$SKIPPED" "$N"
  printf '\n\n'
  printf '%sLegend%s\n' "$B" "$N"
  printf '  %s●%s %s●%s %s●%s  %sgreen %s  %-9s the zone resolves, all name servers answer, serials match\n' \
    "$D" "$N" "$D" "$N" "$G" "$N" "$G" "$N" "OK"
  printf '  %s●%s %s●%s %s●%s  %syellow%s  %-9s the zone does not exist (NXDOMAIN),\n' \
    "$D" "$N" "$Y" "$N" "$D" "$N" "$Y" "$N" "WARNING"
  printf '                           or some name servers do not answer, or serials differ\n'
  printf '  %s●%s %s●%s %s●%s  %sred   %s  %-9s the NS lookup failed (SERVFAIL, REFUSED, TIMEOUT, ...),\n' \
    "$R" "$N" "$D" "$N" "$D" "$N" "$R" "$N" "FAILURE"
  printf '                           or none of the name servers answers\n'
  printf '\n'
  printf '  %sThe light combines the NS lookup and the direct SOA query to each name server.%s\n' "$D" "$N"
  printf '  %sSOA serial in %sred%s%s: the name servers are out of sync.%s\n' "$D" "$R" "$N" "$D" "$N"
  printf '  %s%sRed text%s%s instead of a serial: this name server could not be queried.%s\n' "$D" "$R" "$N" "$D" "$N"
  printf '\n%s       %-30s %-18s %-30s %-12s %s%s\n\n' \
    "$D" "name server" "IPv4" "IPv6" "SOA serial" "rtt" "$N"
}

# --- main loop --------------------------------------------------------------
printf '\033[H\033[2J'
header

while :; do
  rm -f "$TMPD"/*
  for ((i = 0; i < ${#DOMAINS[@]}; i++)); do
    check_domain "${DOMAINS[i]}" "$TMPD/$i" &
  done

  status_line "checking ...   (q / Esc to quit)"
  until all_done; do
    quit_pressed && exit 0
  done
  wait

  screen=$(
    header
    for ((i = 0; i < ${#DOMAINS[@]}; i++)); do cat "$TMPD/$i"; done
  )
  printf '\033[H\033[2J%s\n' "$screen"

  end=$((SECONDS + INTERVAL))
  while (( SECONDS < end )); do
    if (( RESIZED )); then                       # redraw cached screen, no re-query
      RESIZED=0
      printf '\033[H\033[2J%s\n' "$screen"
    fi
    status_line "next check in $((end - SECONDS))s   (q / Esc to quit)"
    quit_pressed && exit 0
  done
done
