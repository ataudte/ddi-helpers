#!/usr/bin/env bash
# =============================================================================
#  dns_watch - DNS & WHOIS drift / hijack monitor for macOS, with live dashboard
# =============================================================================
#  Usage:  ./dns_watch.sh [dns_watch_domains.csv]
#  Keys:   q/Q quit    r/R check now    a/A acknowledge drifts
#
#  Files (next to the script):
#    dns_watch_domains.csv              domains to watch (sample created on first start)
#    dns_watch_results/<domain>.txt     per domain: current status, baseline records,
#                                       history of status updates and drifts
#
#  What raises an alert:
#    CRITICAL  NS / parent (registry) NS / DS / DNSKEY changes, domain NXDOMAIN,
#              WHOIS registrar or nameserver change, transfer lock removed,
#              pendingTransfer / hold status            -> possible hijack
#    HIGH      A, AAAA, CNAME, MX, CAA, SPF/DMARC/DKIM/verification TXT,
#              lookups failing, domain expiring soon
#    MEDIUM    other TXT / record changes, other WHOIS status changes
#
#  Alerts: macOS notifications (Notification Center, with sound).
#
#  Needs only stock macOS tools: bash 3.2, dig, whois, osascript.
# =============================================================================

set -o pipefail
export LC_ALL=C

BASE_DIR="$(cd "$(dirname "$0")" && pwd -P)"

# ------------------------------- settings ------------------------------------
DOMAINS_CSV="$BASE_DIR/dns_watch_domains.csv"
RESULTS_DIR="$BASE_DIR/dns_watch_results"
INTERVAL=30                       # seconds between DNS checks
WHOIS_INTERVAL=21600              # seconds between WHOIS checks (registries rate-limit)
DEFAULT_TYPES="NS A AAAA MX TXT CAA"
RESOLVER="9.9.9.9"                # only used to locate the authoritative servers
DIG_TIMEOUT=2
MAX_PARALLEL=8                    # domains checked at the same time
ERROR_THRESHOLD=3                 # failed checks in a row before status ERROR
EXPIRY_WARN_DAYS=30
ALERT_MIN_SEVERITY="LOW"          # INFO | LOW | MEDIUM | HIGH | CRITICAL

[ -n "${1:-}" ] && DOMAINS_CSV=$1

WORK=""; CHECK_PID=""; OLD_STTY=""
R=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'
GRN=$'\033[32m'; YEL=$'\033[33m'; MAG=$'\033[35m'; CYN=$'\033[36m'

# ------------------------------- helpers -------------------------------------
now()     { date +%s; }
stamp()   { date '+%Y-%m-%d %H:%M:%S'; }
lower()   { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
sev_num() { case "$1" in LOW) echo 1;; MEDIUM) echo 2;; HIGH) echo 3;; CRITICAL) echo 4;; *) echo 0;; esac; }

field() {   # read "KEY value" from the header of a results file
  awk -v k="$2" '/^===/ { exit } $1 == k { $1 = ""; sub(/^ +/, ""); print; exit }' "$1" 2>/dev/null
}

with_timeout() {   # macOS has no `timeout`
  local secs=$1; shift
  "$@" & local pid=$!
  ( sleep "$secs"; kill -9 "$pid" 2>/dev/null ) >/dev/null 2>&1 & local watcher=$!
  wait "$pid"; local rc=$?
  kill "$watcher" 2>/dev/null; wait "$watcher" 2>/dev/null
  return $rc
}

parse_date() {   # WHOIS date formats -> epoch
  local s=$1 e fmt
  for fmt in '%Y-%m-%d:10' '%d-%b-%Y:11' '%Y.%m.%d:10' '%d.%m.%Y:10'; do
    e=$(date -j -u -f "${fmt%:*}" "${s:0:${fmt##*:}}" '+%s' 2>/dev/null) && { echo "$e"; return 0; }
  done
  return 1
}

read_csv() {   # -> "domain,TYPES,yes|no" per line
  sed -e 's/#.*//' -e 's/\r$//' "$DOMAINS_CSV" | awk -F, -v dt="$DEFAULT_TYPES" '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    { d = tolower(trim($1)); sub(/\.$/, "", d); if (d == "" || d == "domain") next
      t = toupper(trim($2)); gsub(/[;|]/, " ", t); if (t == "") t = dt
      w = tolower(trim($3)); if (w == "") w = "yes"
      print d "," t "," w }'
}

# --------------------------------- DNS ---------------------------------------
rq()    { dig +short "+time=$DIG_TIMEOUT" +tries=2 "@$RESOLVER" "$1" "$2" 2>/dev/null; }
ip_of() { rq A "${1%.}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1; }

find_zone() {   # walk up the labels until a name owns an SOA
  local n=$1
  while :; do
    if dig +noall +answer "+time=$DIG_TIMEOUT" +tries=2 "@$RESOLVER" SOA "$n" 2>/dev/null \
        | awk -v n="$n." 'tolower($1) == n && toupper($4) == "SOA" { f = 1 } END { exit !f }'; then
      echo "$n"; return 0
    fi
    case "$n" in *.*) n=${n#*.} ;; *) return 1 ;; esac
  done
}

auth_ips() { local h; rq NS "$1" | while read -r h; do ip_of "$h"; done | sort -u; }

# dig_query SERVER NAME TYPE OUTFILE [extra flag]  (non-recursive, normalized, sorted)
dig_query() {
  local raw st
  raw=$(dig +noall +answer +comments +norec "+time=$DIG_TIMEOUT" +tries=2 "@$1" "$2" "$3" ${5:+"$5"} 2>/dev/null) || return 1
  st=$(printf '%s\n' "$raw" | sed -n 's/.*status: \([A-Z]*\).*/\1/p' | head -n1)
  case "$st" in
    NOERROR) ;;
    NXDOMAIN) printf '%s. NXDOMAIN -\n' "$2" > "$4"; return 0 ;;
    *) return 1 ;;
  esac
  printf '%s\n' "$raw" | awk '
    /^;/ || NF < 5 { next }
    { t = toupper($4); if (t == "RRSIG") next
      rd = ""; for (i = 5; i <= NF; i++) rd = rd (i > 5 ? " " : "") $i
      if (t != "TXT") rd = tolower(rd)
      print tolower($1), t, rd }' | sort -u > "$4"
}

parent_ns() {   # NS of ZONE as published by the registry (parent zone)
  local zone=$1 out=$2 pz p ip
  case "$zone" in *.*) ;; *) return 1 ;; esac
  pz=$(find_zone "${zone#*.}") || return 1
  for p in $(rq NS "$pz" | head -n 3); do
    ip=$(ip_of "$p"); [ -n "$ip" ] || continue
    if dig_query "$ip" "$zone" NS "$out.raw" +authority; then
      awk -v z="$zone." '$1 == z && $2 == "NS" { print "PARENT_NS", $3 }' "$out.raw" | sort -u > "$out"
      rm -f "$out.raw"; [ -s "$out" ] && return 0
    fi
  done
  return 1
}

whois_fetch() {   # registry WHOIS -> "WHOIS key value" lines
  local server raw
  server=$(with_timeout 15 whois -h whois.iana.org "${1##*.}" 2>/dev/null \
           | awk -F: 'tolower($1) == "refer" { gsub(/[ \t\r]/, "", $2); print $2; exit }')
  [ -n "$server" ] || return 1
  raw=$(with_timeout 20 whois -h "$server" "$1" 2>/dev/null)
  printf '%s\n' "$raw" | awk '
    function trim(s) { gsub(/^[ \t]+|[ \t\r]+$/, "", s); return s }
    index($0, ":") == 0 { next }
    { k = tolower(trim(substr($0, 1, index($0, ":") - 1)))
      v = trim(substr($0, index($0, ":") + 1)); if (v == "") next
      split(v, w, /[ \t]+/)
      if (k == "registrar" || k == "sponsoring registrar") print "WHOIS registrar " v
      else if (k == "domain status" || k == "status") print "WHOIS status " tolower(w[1])
      else if (k == "name server" || k == "nserver" || k == "nameserver") {
        h = tolower(w[1]); sub(/\.$/, "", h); print "WHOIS nameserver " h }
      else if (k ~ /expir|paid-till/) print "WHOIS expiry " w[1] }' | sort -u > "$2"
  [ -s "$2" ]
}

# ------------------------------ alerting -------------------------------------
alert() {   # SEVERITY DOMAIN MESSAGE -> macOS notification
  local sev=$1 name=$2 msg=$3 sound=Glass
  [ "$(sev_num "$sev")" -ge "$(sev_num "$ALERT_MIN_SEVERITY")" ] || return 0
  [ "$sev" = CRITICAL ] && sound=Sosumi
  osascript -e 'on run argv' \
    -e 'display notification (item 2 of argv) with title "dns_watch" subtitle (item 1 of argv) sound name (item 3 of argv)' \
    -e 'end run' "[$sev] $name" "$msg" "$sound" >/dev/null 2>&1
  return 0
}

sev_for() {   # one change line -> severity
  local act type fld rest l
  read -r act type fld rest <<EOF
$1
EOF
  act=$(lower "$act"); type=${type%:}; fld=${fld%:}; l=$(lower "$1")
  case "$type" in
    NXDOMAIN|NS|PARENT_NS|DS|DNSKEY) echo CRITICAL ;;
    WHOIS)
      case "$fld" in
        registrar|nameserver) echo CRITICAL ;;
        status)
          case "$act:$l" in
            *pending*|*hold*|*redemption*|removed:*prohibited*|modified:*prohibited*) echo CRITICAL ;;
            added:*prohibited*) echo LOW ;;
            *) echo MEDIUM ;;
          esac ;;
        expiry) echo LOW ;;
        *) echo MEDIUM ;;
      esac ;;
    A|AAAA|CNAME|MX|CAA) echo HIGH ;;
    TXT) case "$l" in *spf1*|*dmarc*|*domainkey*|*verification*) echo HIGH ;; *) echo MEDIUM ;; esac ;;
    SOA) echo INFO ;;
    *) echo MEDIUM ;;
  esac
}

diff_lines() {   # REMOVED_FILE ADDED_FILE -> ADDED / REMOVED / MODIFIED lines
  awk '
    function nk(s,  f) { split(s, f, " "); return (f[1] == "WHOIS") ? 2 : 1 }
    function key(s,  f, k, i, o) { k = nk(s); split(s, f, " "); o = f[1]; for (i = 2; i <= k; i++) o = o " " f[i]; return o }
    function rest(s,  f, n, i, k, o) { k = nk(s); n = split(s, f, " "); o = ""
      for (i = k + 1; i <= n; i++) o = o (i > k + 1 ? " " : "") f[i]; return o }
    FILENAME == ARGV[1] { nr++; Rm[nr] = $0; rc[key($0)]++; next }
    { na++; Ad[na] = $0; ac[key($0)]++ }
    END {
      for (i = 1; i <= nr; i++) { k = key(Rm[i])
        if (rc[k] == 1 && ac[k] == 1) mod[k] = rest(Rm[i]); else print "REMOVED  " Rm[i] }
      for (i = 1; i <= na; i++) { k = key(Ad[i])
        if (k in mod) print "MODIFIED " k ": " mod[k] " -> " rest(Ad[i]); else print "ADDED    " Ad[i] }
    }' "$1" "$2"
}

# ------------------------------- checker -------------------------------------
check_domain() {   # NAME "TYPES" yes|no
  local name=$1 types=$2 whois=$3
  local f="$RESULTS_DIR/$name.txt" w="$WORK/chk.$name"
  local status since unacked drifts errors last_whois expires exp_alerted last_event
  local zone ips t ip ok=0 failed="" changes line sev max=INFO n newstatus exp e days
  mkdir -p "$w"; : > "$w/old"; : > "$w/hist"; : > "$w/new"; : > "$w/ev"

  if [ -f "$f" ]; then
    status=$(field "$f" STATUS); since=$(field "$f" STATUS_SINCE); unacked=$(field "$f" UNACKED)
    drifts=$(field "$f" DRIFTS); errors=$(field "$f" ERRORS); last_whois=$(field "$f" LAST_WHOIS)
    expires=$(field "$f" EXPIRES); exp_alerted=$(field "$f" EXPIRY_ALERTED); last_event=$(field "$f" LAST_EVENT)
    awk '/^=== HISTORY ===/ { exit } b { print } /^=== BASELINE ===/ { b = 1 }' "$f" > "$w/old"
    awk 'h { print } /^=== HISTORY ===/ { h = 1 }' "$f" | tail -n 2000 > "$w/hist"
  fi
  status=${status:-NEW}; since=${since:-$(stamp)}; unacked=${unacked:--}; drifts=${drifts:-0}
  errors=${errors:-0}; last_whois=${last_whois:-0}; expires=${expires:--}
  exp_alerted=${exp_alerted:--}; last_event=${last_event:--}

  # --- DNS records straight from the authoritative servers (no caches) ---
  zone=$(find_zone "$name")
  if [ -z "$zone" ]; then
    failed=" zone-lookup"
    grep -v '^WHOIS ' "$w/old" >> "$w/new"        # keep old data, don't fake removals
  else
    ips=$(auth_ips "$zone")
    for t in $types; do
      for ip in $ips; do
        if dig_query "$ip" "$name" "$t" "$w/q"; then
          awk '{ $1 = ""; sub(/^ /, ""); print }' "$w/q" >> "$w/new"; ok=$((ok + 1)); continue 2
        fi
      done
      failed="$failed $t"
      grep "^$t " "$w/old" >> "$w/new"
    done
    if [ "$zone" = "$name" ]; then                  # registry delegation = hijack signal
      if parent_ns "$zone" "$w/p"; then cat "$w/p" >> "$w/new"; ok=$((ok + 1))
      else failed="$failed PARENT_NS"; grep '^PARENT_NS ' "$w/old" >> "$w/new"; fi
    fi
  fi

  # --- WHOIS, only every WHOIS_INTERVAL ---
  if [ "$whois" = yes ] && [ "$zone" = "$name" ] && [ $(( $(now) - last_whois )) -ge "$WHOIS_INTERVAL" ]; then
    if whois_fetch "$name" "$w/wh"; then cat "$w/wh" >> "$w/new"; last_whois=$(now)
    else grep '^WHOIS ' "$w/old" >> "$w/new"; last_whois=$(( $(now) - WHOIS_INTERVAL + 900 )); fi
  else
    grep '^WHOIS ' "$w/old" >> "$w/new"
  fi
  sort -u -o "$w/new" "$w/new"
  if [ "$ok" = 0 ]; then errors=$((errors + 1)); else errors=0; fi

  # --- drift detection ---
  if [ ! -s "$w/old" ]; then
    if [ -s "$w/new" ]; then
      n=$(wc -l < "$w/new" | tr -d ' ')
      last_event="baseline captured ($n records)"
      echo "$(stamp)  BASELINE  $last_event" >> "$w/ev"
    fi
  elif ! cmp -s "$w/old" "$w/new"; then
    comm -23 "$w/old" "$w/new" > "$w/rm"; comm -13 "$w/old" "$w/new" > "$w/add"
    changes=$(diff_lines "$w/rm" "$w/add")
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      sev=$(sev_for "$line")
      echo "$(stamp)  DRIFT     [$sev] $line" >> "$w/ev"
      drifts=$((drifts + 1))
      [ "$(sev_num "$sev")" -gt "$(sev_num "$max")" ] && max=$sev
    done <<EOF
$changes
EOF
    last_event="[$max] $(printf '%s\n' "$changes" | head -n1)"
    if [ "$max" != INFO ] && { [ "$unacked" = - ] || [ "$(sev_num "$max")" -gt "$(sev_num "$unacked")" ]; }; then
      unacked=$max
    fi
    alert "$max" "$name" "$changes"
  fi

  # --- expiry warning ---
  exp=$(awk '$1 == "WHOIS" && $2 == "expiry" { print $3; exit }' "$w/new")
  if [ -n "$exp" ] && e=$(parse_date "$exp"); then
    expires=$exp
    days=$(( (e - $(now)) / 86400 ))
    if [ "$days" -le "$EXPIRY_WARN_DAYS" ] && [ "$exp_alerted" != "$exp" ]; then
      exp_alerted=$exp; last_event="domain expires in $days days"
      echo "$(stamp)  EXPIRY    [HIGH] $last_event ($exp)" >> "$w/ev"
      alert HIGH "$name" "Domain registration expires in $days days ($exp)."
    fi
  fi

  # --- status ---
  if   [ "$errors" -ge "$ERROR_THRESHOLD" ]; then newstatus=ERROR
  elif [ ! -s "$w/new" ];                  then newstatus=NEW
  elif [ "$unacked" = CRITICAL ];          then newstatus=ALERT
  elif [ "$unacked" != - ];                then newstatus=DRIFT
  else                                          newstatus=OK
  fi
  if [ "$newstatus" != "$status" ]; then
    since=$(stamp)
    echo "$(stamp)  STATUS    $status -> $newstatus${failed:+ (failed:$failed)}" >> "$w/ev"
    if [ "$newstatus" = ERROR ]; then
      last_event="lookups failing:$failed"
      alert HIGH "$name" "DNS lookups failed $errors times in a row (failed:$failed). Outage, expired domain or hijacked delegation?"
    elif [ "$status" = ERROR ]; then
      alert LOW "$name" "DNS lookups are working again."
    fi
  fi

  # --- write results file atomically ---
  {
    echo "# dns_watch results for $name  (status, baseline, history)"
    printf '%-15s %s\n' DOMAIN "$name" STATUS "$newstatus" STATUS_SINCE "$since" LAST_CHECK "$(stamp)" \
      UNACKED "$unacked" DRIFTS "$drifts" ERRORS "$errors" RECORDS "$(wc -l < "$w/new" | tr -d ' ')" \
      EXPIRES "$expires" EXPIRY_ALERTED "$exp_alerted" LAST_WHOIS "$last_whois" LAST_EVENT "$last_event"
    echo "=== BASELINE ==="; cat "$w/new"
    echo "=== HISTORY ==="; cat "$w/hist" "$w/ev"
  } > "$f.tmp" && mv "$f.tmp" "$f"
  rm -rf "$w"
}

run_checks() {
  local d t w n=0
  read_csv > "$WORK/chk.list"
  while IFS=, read -r d t w; do
    check_domain "$d" "$t" "$w" &
    n=$((n + 1)); if [ "$n" -ge "$MAX_PARALLEL" ]; then wait; n=0; fi
  done < "$WORK/chk.list"
  wait
}

ack_all() {   # DRIFT / ALERT -> OK
  local f
  for f in "$RESULTS_DIR"/*.txt; do
    [ -f "$f" ] || continue
    [ "$(field "$f" UNACKED)" = - ] && continue
    awk -v ts="$(stamp)" '
      /^=== BASELINE ===/ { body = 1 }
      !body && $1 == "UNACKED" { printf "%-15s %s\n", "UNACKED", "-"; next }
      !body && $1 == "STATUS" && ($2 == "DRIFT" || $2 == "ALERT") { printf "%-15s %s\n", "STATUS", "OK"; next }
      { print }
      END { print ts "  ACK       drifts acknowledged, status -> OK" }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  done
}

# ------------------------------ dashboard ------------------------------------
status_color() {
  case "$1" in OK) echo "$GRN";; DRIFT) echo "$YEL";; ALERT) echo "$BOLD$RED";; ERROR) echo "$MAG";; *) echo "$DIM";; esac
}

draw() {
  local next=$1 cols rows out n d t w f st lc rec dr ex le e days sp exs line col evw evn left
  local EL=$'\033[K\n'
  cols=$(tput cols 2>/dev/null || echo 120); rows=$(tput lines 2>/dev/null || echo 40)
  read_csv > "$WORK/ui.list"; n=$(wc -l < "$WORK/ui.list" | tr -d ' ')

  out="${BOLD}${CYN}dns_watch${R}  $(stamp)   $n domains   every ${INTERVAL}s   "
  if [ -n "$CHECK_PID" ]; then out+="${YEL}checking...${R}"
  else left=$(( next - $(now) )); [ "$left" -lt 0 ] && left=0; out+="next check in ${left}s"; fi
  out+="$EL$EL"
  printf -v line '%-32s %-7s %-9s %-7s %-6s %-8s %s' DOMAIN STATUS CHECKED RECORDS DRIFTS EXPIRES "LAST EVENT"
  out+="$BOLD$line$R$EL"
  evw=$(( cols - 76 )); [ "$evw" -lt 10 ] && evw=10

  while IFS=, read -r d t w; do
    f="$RESULTS_DIR/$d.txt"
    st=NEW; lc=-; rec=-; dr=-; ex=-; le="waiting for first check"
    if [ -f "$f" ]; then
      IFS='|' read -r st lc rec dr ex le <<EOF
$(awk '/^===/ { exit } { k = $1; $1 = ""; sub(/^ +/, ""); v[k] = $0 }
       END { print v["STATUS"] "|" v["LAST_CHECK"] "|" v["RECORDS"] "|" v["DRIFTS"] "|" v["EXPIRES"] "|" v["LAST_EVENT"] }' "$f")
EOF
      lc=${lc#* }
    fi
    printf -v exs '%-8s' -
    if [ "$ex" != - ] && [ -n "$ex" ] && e=$(parse_date "$ex"); then
      days=$(( (e - $(now)) / 86400 )); printf -v exs '%-8s' "${days}d"
      [ "$days" -le "$EXPIRY_WARN_DAYS" ] && exs="$RED$exs$R"
    fi
    printf -v sp '%-7s' "$st"
    printf -v line '%-32.32s %s %-9s %-7s %-6s %s %s' "$d" "$(status_color "$st")$sp$R" "$lc" "$rec" "$dr" "$exs" "${le:0:$evw}"
    out+="$line$EL"
  done < "$WORK/ui.list"

  out+="$EL${BOLD}Recent events${R}$EL"
  evn=$(( rows - n - 9 )); [ "$evn" -lt 1 ] && evn=1
  for f in "$RESULTS_DIR"/*.txt; do
    [ -f "$f" ] || continue
    awk -v d="$(basename "$f" .txt)" 'h { print substr($0, 1, 19) "  " d "  " substr($0, 22) } /^=== HISTORY ===/ { h = 1 }' "$f"
  done | sort -s -k1,2 | tail -n "$evn" > "$WORK/ui.ev"
  while IFS= read -r line; do
    case "$line" in *CRITICAL*) col=$BOLD$RED;; *HIGH*|*DRIFT*) col=$YEL;; *ERROR*) col=$MAG;; *) col=$DIM;; esac
    line=${line:5}
    out+="$col${line:0:$((cols - 1))}$R$EL"
  done < "$WORK/ui.ev"

  out+="$EL${DIM}[q] quit   [r] check now   [a] acknowledge drifts   results: $RESULTS_DIR$R$EL"
  printf '\033[H%s\033[J' "$out"
}

cleanup() {
  if [ -n "$CHECK_PID" ]; then pkill -P "$CHECK_PID" 2>/dev/null; kill "$CHECK_PID" 2>/dev/null; fi
  [ -n "$OLD_STTY" ] && stty "$OLD_STTY" 2>/dev/null
  tput cnorm 2>/dev/null
  printf '%s\033[2J\033[Hdns_watch stopped. Results are in %s\n' "$R" "$RESULTS_DIR"
  [ -n "$WORK" ] && rm -rf "$WORK"
}

main() {
  local cmd next=0 ack=0 key
  for cmd in dig whois osascript; do command -v "$cmd" >/dev/null || { echo "$cmd not found"; exit 1; }; done
  if [ ! -f "$DOMAINS_CSV" ]; then
    cat > "$DOMAINS_CSV" <<'EOF'
# dns_watch domains
# domain, record types (space separated, empty = default), whois (yes/no)
# Parent-NS and WHOIS checks run only for registered domains (zone apex).
domain,types,whois
example.com,,yes
www.example.com,CNAME A AAAA,no
_dmarc.example.com,TXT,no
EOF
    echo "Created $DOMAINS_CSV - add your domains there and start again."
    exit 0
  fi
  [ -t 0 ] || { echo "Please run dns_watch in a terminal."; exit 1; }

  mkdir -p "$RESULTS_DIR"
  WORK=$(mktemp -d "${TMPDIR:-/tmp}/dns_watch.XXXXXX") || exit 1
  OLD_STTY=$(stty -g); stty -echo
  trap cleanup EXIT
  trap 'exit 0' INT TERM HUP
  tput civis 2>/dev/null; printf '\033[2J'

  while :; do
    if [ -n "$CHECK_PID" ] && ! kill -0 "$CHECK_PID" 2>/dev/null; then
      wait "$CHECK_PID" 2>/dev/null; CHECK_PID=""
    fi
    if [ -z "$CHECK_PID" ]; then
      [ "$ack" = 1 ] && { ack_all; ack=0; }
      if [ "$(now)" -ge "$next" ]; then
        next=$(( $(now) + INTERVAL ))
        run_checks >/dev/null 2>&1 &
        CHECK_PID=$!
      fi
    fi
    draw "$next"
    key=""; read -rsn1 -t 1 key
    case "$key" in
      q|Q) exit 0 ;;
      r|R) next=0 ;;
      a|A) ack=1 ;;
    esac
  done
}

main
