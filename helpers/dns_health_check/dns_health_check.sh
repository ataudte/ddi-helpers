#!/usr/bin/env bash

GIVEN_DOMAIN="$1"
DNS_SERVER="${2:-9.9.9.9}"

if [[ -z "$GIVEN_DOMAIN" ]]; then
  echo "Usage: $0 <domain> [dns-server]"
  exit 1
fi

DOMAIN=$(echo "$GIVEN_DOMAIN" | sed 's/\.$//')

# Logging
script=$(basename "$0")
server=$(hostname)
scriptFolder=$(dirname "$(readlink -f "$0")")
log="${scriptFolder}/${script%.sh}_${server}_$(date '+%Y%m%d-%H%M%S').log"
> "$log"

function msg() {
  case "$2" in
    "error") logPrefix="# ERROR #" ;;
    "warn") logPrefix="# WARN  #" ;;
    "head") logPrefix="# ///// #" ;;
    *) logPrefix="#       #" ;;
  esac
  
  echo -e "${logPrefix} $1"
  echo -e "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> "$log"
}

# Running
msg "========================================================"
msg "Running DNS Health Check for $DOMAIN"
msg "========================================================"

# Get the authoritative nameservers of the parent zone
PARENT_DOMAIN=$(echo "$DOMAIN" | sed 's/^[^.]*\.//')

msg "Delegations" "head"
PARENT_AUTH_NS=$(dig SOA $PARENT_DOMAIN +short @$DNS_SERVER | awk '{print $1}')
if [[ -z "$PARENT_AUTH_NS" ]]; then
  msg "Could not determine authoritative NS for parent zone." "error"
else
  msg "Authoritative NS for $PARENT_DOMAIN: $PARENT_AUTH_NS"
fi

# Fetch NS records (from parent authoritative NS)
if [[ -n "$PARENT_AUTH_NS" ]]; then
  PARENT_NS=$(dig @$PARENT_AUTH_NS $DOMAIN. +noall +authority | awk '{print tolower($5)}' | sort)
  if [[ -z "$PARENT_NS" ]]; then
    msg "No NS records found at parent." "error"
  else
    msg "Parent NS Records:"
    msg "$(echo "$PARENT_NS" | tr '\n' ',' | sed 's/,$//')"

  fi
fi

# Fetch authoritative NS records
CHILD_NS=$(dig @$DNS_SERVER $DOMAIN NS +noall +answer | awk '{print tolower($5)}' | sort)
if [[ -z "$CHILD_NS" ]]; then
  msg "No NS records found at child." "error"
else
  msg "Child NS Records:"
  msg "$(echo "$CHILD_NS" | tr '\n' ',' | sed 's/,$//')"
fi

# Compare Parent vs. Child NS records
if [[ "$PARENT_NS" != "$CHILD_NS" ]]; then
  msg "Parent and Child NS records do not match!" "warn"
else
  msg "Parent and Child NS records match."
fi

msg "NS Validation" "head"
for NS in $(dig NS $DOMAIN +short @$DNS_SERVER); do

  # Query the NS server for its own NS records
  RESPONSE=$(dig SOA $DOMAIN @$NS +short)

  if [[ -z "$RESPONSE" ]]; then
    msg "$NS does not respond to queries for $DOMAIN!" "error"
  else
    msg "$NS responds or $DOMAIN correctly: $RESPONSE"
  fi
done

# Check SOA Records
SOA_RESULTS=()
SERIAL_NUMBERS=()
MNAME_LIST=()
RNAME_LIST=()
TIMERS_LIST=()

# Run +nssearch to get SOA details from each NS
SOA_OUTPUT=$(dig +nssearch $DOMAIN @$DNS_SERVER 2>/dev/null)

if [[ -z "$SOA_OUTPUT" ]]; then
  msg "Failed to retrieve SOA records using +nssearch." "error"
else
  msg "Retrieved SOA records from all NS servers."

  # Process each SOA response
  while read -r line; do
    if [[ "$line" =~ ^SOA ]]; then
      NS=$(echo "$line" | awk '{print $11}')  # Last field (IP of NS)
      MNAME=$(echo "$line" | awk '{print $2}')
      RNAME=$(echo "$line" | awk '{print $3}')
      SERIAL=$(echo "$line" | awk '{print $4}')
      REFRESH=$(echo "$line" | awk '{print $5}')
      RETRY=$(echo "$line" | awk '{print $6}')
      EXPIRE=$(echo "$line" | awk '{print $7}')
      NEGATIVE_TTL=$(echo "$line" | awk '{print $8}')

      # Ensure values are correctly parsed
      if [[ -n "$MNAME" && -n "$RNAME" && -n "$SERIAL" && -n "$REFRESH" && -n "$RETRY" && -n "$EXPIRE" && -n "$NEGATIVE_TTL" ]]; then
        SOA_RESULTS+=("SERIAL: $SERIAL, MNAME: $MNAME, RNAME: $RNAME, REFRESH: $REFRESH, RETRY: $RETRY, EXPIRE: $EXPIRE, NEGATIVE TTL: $NEGATIVE_TTL -> $NS")
        SERIAL_NUMBERS+=("$SERIAL")
        MNAME_LIST+=("$MNAME")
        RNAME_LIST+=("$RNAME")
        TIMERS_LIST+=("$REFRESH $RETRY $EXPIRE $NEGATIVE_TTL")
      else
        msg "Could not parse SOA record from $NS. Output may be malformed." "warn"
      fi
    fi
  done <<< "$SOA_OUTPUT"

  # Display gathered SOA records
  msg "SOA Records:"
  for RECORD in "${SOA_RESULTS[@]}"; do
    msg "$RECORD"
  done

  # Check Serial Number Consistency
  UNIQUE_SERIALS=$(printf "%s\n" "${SERIAL_NUMBERS[@]}" | sort -u | wc -l)
  if [[ $UNIQUE_SERIALS -gt 1 ]]; then
    msg "SOA serial numbers are inconsistent across NS servers!" "warn"
  else
    msg "SOA serial numbers match across all NS servers."
  fi

  # Check MNAME Consistency
  UNIQUE_MNAMES=$(printf "%s\n" "${MNAME_LIST[@]}" | sort -u | wc -l)
  if [[ $UNIQUE_MNAMES -gt 1 ]]; then
    msg "SOA MNAME values are inconsistent!" "warn"
  else
    msg "SOA MNAME values match across all NS servers."
  fi

  # Check RNAME Consistency
  UNIQUE_RNAMES=$(printf "%s\n" "${RNAME_LIST[@]}" | sort -u | wc -l)
  if [[ $UNIQUE_RNAMES -gt 1 ]]; then
    msg "SOA RNAME values are inconsistent!" "warn"
  else
    msg "SOA RNAME values match across all NS servers."
  fi

  # Check SOA Timer Consistency
  UNIQUE_TIMERS=$(printf "%s\n" "${TIMERS_LIST[@]}" | sort -u | wc -l)
  if [[ $UNIQUE_TIMERS -gt 1 ]]; then
    msg "SOA timers (REFRESH, RETRY, EXPIRE, NEGATIVE TTL) are inconsistent!" "warn"
  else
    msg "SOA timers match across all NS servers."
  fi
fi

msg "DNSSEC-related Records" "head"
# Check DS Records at the Parent Zone
if [[ -n "$PARENT_AUTH_NS" ]]; then
  DS_PARENT=$(dig DS $DOMAIN @$PARENT_AUTH_NS +short)
  if [[ -z "$DS_PARENT" ]]; then
    msg "No DS records found at parent zone." "warn"
  else
    msg "Parent DS Records:"
    msg "$DS_PARENT"
  fi
fi

# Check DS Records at the Parent Zone
DS_CHILD=$(dig DS $DOMAIN +short @$DNS_SERVER)
if [[ -z "$DS_CHILD" ]]; then
  msg "No DNSKEY records found at child zone." "warn"
else
  msg "Child DNSKEY Record:"
  msg "$DS_CHILD"
fi


# Check MX, SPF, DKIM, and DMARC records
msg "Mail-related Records" "head"
# MX records
MX_RECORDS=$(dig MX $DOMAIN +short @$DNS_SERVER)
if [[ -z "$MX_RECORDS" ]]; then
  msg "No MX records found." "warn"
else
  msg "MX Records:"
  msg "$(echo "$MX_RECORDS" | tr '\n' ',' | sed 's/,$//')"
fi

# SPF (TXT) records
SPF_RECORD=$(dig TXT $DOMAIN +short @$DNS_SERVER | grep -i "v=spf1")
if [[ -z "$SPF_RECORD" ]]; then
  msg "No SPF record found!" "warn"
else
  msg "SPF Records:"
  msg "$(echo "$SPF_RECORD" | tr '\n' ',' | sed 's/,$//')"
fi

# DKIM (TXT) records
DKIM_SELECTORS=${DKIM_SELECTORS:-"\
                 cf1        # Cloudflare
                 csi        # Cisco IronPort
                 default    # Generic default
                 dkim       # DKIM base selector
                 dkim1      # DKIM increment 1
                 dkim2      # DKIM increment 2
                 email      # Generic email selector
                 fm1        # Fastmail selector 1
                 fm2        # Fastmail selector 2
                 google     # Google Workspace legacy selector
                 k1         # Mailchimp selector
                 mail       # Generic mail selector
                 s1         # Common SaaS selector 1
                 s2         # Common SaaS selector 2
                 selector   # Generic selector
                 selector1  # Generic / Microsoft selector 1
                 selector2  # Generic / Microsoft selector 2
               "}
FOUND_DKIM=()
for SEL in $DKIM_SELECTORS; do
  DKIM_RECORD=$(dig +short TXT "${SEL}._domainkey.${DOMAIN}" @"$DNS_SERVER")
  if [[ -n "$DKIM_RECORD" ]]; then
    # flatten possible multi-line TXT into a single line
    DKIM_RECORD_ONELINE=$(echo "$DKIM_RECORD" | tr '\n' ' ')
    FOUND_DKIM+=("${SEL}: ${DKIM_RECORD_ONELINE}")
  fi
done
if ((${#FOUND_DKIM[@]} == 0)); then
  msg "No DKIM records found for selectors: ${DKIM_SELECTORS}" "warn"
else
  msg "DKIM records found:"
  for entry in "${FOUND_DKIM[@]}"; do
    msg "  ${entry}"
  done
fi

# DMARC (TXT) records
DMARC_RECORD=$(dig TXT _dmarc.$DOMAIN +short @$DNS_SERVER)
if [[ -z "$DMARC_RECORD" ]]; then
  msg "No DMARC record found!" "warn"
else
  msg "DMARC Records:"
  msg "$(echo "$DMARC_RECORD" | tr '\n' ',' | sed 's/,$//')"
fi

msg "NS Configuration" "head"
# Minimum TTL (Negative TTL)
NEGATIVE_TTL=$(dig SOA $DOMAIN +short @$DNS_SERVER | awk '{print $7}')
if [[ -n "$NEGATIVE_TTL" ]]; then
  msg "Negative TTL (Minimum TTL): $NEGATIVE_TTL seconds"
else
  msg "Unable to determine Negative TTL." "error"
fi

# Zone Transfer Test
for NS in $(dig NS $DOMAIN +short @$DNS_SERVER); do
  AXFR=$(dig AXFR $DOMAIN @$NS 2>&1)
  if echo "$AXFR" | grep -q "Transfer failed"; then
    msg "Zone Transfer for $DOMAIN disabled on $NS"
  else
    msg "Zone Transfer for $DOMAIN on $NS" "warn"
  fi
done

# Dynamic DNS Test
for NS in $(dig NS $DOMAIN +short @$DNS_SERVER); do
  printf "server $NS\nzone $DOMAIN\nupdate add test-record.$DOMAIN 60 A 192.0.2.1\nsend\n" \
         | nsupdate -v >/dev/null 2>&1 \
         && msg "Dynamic Update for $DOMAIN on $NS allowed" "error" \
         || msg "Dynamic update for $DOMAIN on $NS refused"
done

msg "Reachability Check" "head"
ping -c 2 -W 2 $DOMAIN >/dev/null 2>&1
if [[ $? -ne 0 ]]; then
  msg "$DOMAIN is not responding to ping." "warn"
else
  msg "$DOMAIN responds to ping."
fi

for NS in $(dig NS $DOMAIN +short @$DNS_SERVER); do
  # Check UDP port 53
  nc -uz -w3 $NS 53 >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    msg "$NS is reachable over UDP (port 53)."
  else
    msg "$NS is NOT reachable over UDP (port 53)." "error"
  fi

  # Check TCP port 53
  nc -z -w3 $NS 53 >/dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    msg "$NS is reachable over TCP (port 53)."
  else
    msg "$NS is NOT reachable over TCP (port 53)." "error"
  fi
done

# Function to get ASN using ipinfo.io API
get_asn_api() {
    local ip="$1"
    asn_info=$(curl -s "https://ipinfo.io/$ip/org")
    echo "$asn_info"
}

# Extract NS servers dynamically using dig +nssearch
NS_SERVERS=()
while read -r line; do
    NS=$(echo "$line" | awk '{print $11}')
    if [[ -n "$NS" ]]; then
        NS_SERVERS+=("$NS")
    fi
done < <(dig +nssearch "$DOMAIN" @"$DNS_SERVER" 2>/dev/null)

# Collect AS numbers of the extracted NS servers
declare -A asn_counts

for ns in "${NS_SERVERS[@]}"; do
    asn=$(get_asn_api "$ns")
    msg "ASN: $asn -> $ns"
    asn_counts["$asn"]=1
done

# Check if all ASNs are the same
if [ ${#asn_counts[@]} -eq 1 ]; then
    msg "All NS servers belong to the same ASN." "warn"
else
    msg "NS servers are distributed across different ASNs."
fi

msg "========================================================"
msg "DNS Health Check for $DOMAIN completed!"
msg "========================================================"
