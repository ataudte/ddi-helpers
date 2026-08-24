#!/usr/bin/env bash

# Check whether a recursive DNS resolver signals a given DNSSEC trust anchor.
#
# Usage:
#   ./check-ksk.sh <resolver-ip> <key-tag>
#

set -u

RESOLVER="${1:-}"
KEY_TAG="${2:-}"

if [[ -z "$RESOLVER" || -z "$KEY_TAG" ]]; then
    echo "Usage: $0 <resolver-ip> <key-tag>"
    exit 2
fi

# Check dependencies.
for cmd in dig python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is required"
        exit 2
    fi
done

# Validate the resolver address.
if ! python3 -c \
    'import ipaddress, sys; ipaddress.ip_address(sys.argv[1])' \
    "$RESOLVER" 2>/dev/null; then
    echo "ERROR: resolver must be a valid IPv4 or IPv6 address"
    exit 2
fi

# Validate the key tag.
if ! [[ "$KEY_TAG" =~ ^[0-9]+$ ]] || (( KEY_TAG < 0 || KEY_TAG > 65535 )); then
    echo "ERROR: key tag must be an integer between 0 and 65535"
    exit 2
fi

# Convert the decimal key tag to its four-digit hexadecimal form.
printf -v KEY_TAG_HEX "%04x" "$KEY_TAG"

echo "  "
echo "## Check DNSSEC Trust Anchor"
echo "   Resolver: $RESOLVER"
echo "   Key Tag:  $KEY_TAG"
echo "   Hex Tag:  $KEY_TAG_HEX"
echo "  "

# Check DNS resolution.
echo "// DNS Resolution Check"
echo "   dig @${RESOLVER} . SOA +time=3 +tries=1 +short"

if ! dig @"$RESOLVER" . SOA +time=3 +tries=1 +short >/dev/null 2>&1; then
    echo "   DNS Resolution: FAIL"
    echo "  "
    exit 1
fi

echo "   DNS Resolution: PASS"

# Query the resolver using the trust-anchor signaling name.
TA_QUERY="_ta-${KEY_TAG_HEX}."

echo "  "
echo "// Trust Anchor Signaling Check (RFC 8145)"
echo "   dig @${RESOLVER} ${TA_QUERY} NULL +time=3 +tries=1"

TA_OUTPUT=$(
    dig @"$RESOLVER" "$TA_QUERY" NULL \
        +time=3 +tries=1 2>/dev/null
)

if grep -qi "$KEY_TAG_HEX" <<< "$TA_OUTPUT"; then
    echo "   Trust Anchor: PASS"
    echo "  "
    exit 0
fi

echo "   Trust Anchor: NOT CONFIRMED"
echo "  "
exit 1