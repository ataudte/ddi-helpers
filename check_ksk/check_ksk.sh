#!/usr/bin/env bash

# Check whether a recursive DNS resolver trusts a given
# root DNSSEC trust anchor using RFC 8509.
#
# Usage:
#   ./check_ksk.sh <resolver-ip> <key-tag>
#
# Exit codes:
#   0  Trust anchor confirmed
#   1  Trust anchor not confirmed
#   2  Usage, input, or dependency error
#   3  Indeterminate or unsupported

set -u

RESOLVER="${1:-}"
KEY_TAG="${2:-}"

TEST_DOMAIN="d2a8n3.rootcanary.net."
BOGUS_NAME="bogus.${TEST_DOMAIN}"

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

# Format the key tag for the sentinel labels.
printf -v KEY_TAG_PADDED "%05d" "$KEY_TAG"

IS_TA_NAME="root-key-sentinel-is-ta-${KEY_TAG_PADDED}.${TEST_DOMAIN}"
NOT_TA_NAME="root-key-sentinel-not-ta-${KEY_TAG_PADDED}.${TEST_DOMAIN}"

# Execute a query and extract the response status and answer count.
query_dns() {
    local name="$1"
    shift

    local output
    local rc

    output=$(
        dig @"$RESOLVER" "$name" A \
            +dnssec +time=3 +tries=1 "$@" 2>&1
    )
    rc=$?

    if (( rc != 0 )); then
        QUERY_STATUS="ERROR"
        QUERY_ANSWERS="0"
        return
    fi

    QUERY_STATUS=$(
        awk '
            /HEADER/ {
                for (i = 1; i <= NF; i++) {
                    if ($i == "status:") {
                        gsub(",", "", $(i+1))
                        print $(i+1)
                        exit
                    }
                }
            }
        ' <<< "$output"
    )

    QUERY_ANSWERS=$(
        awk '
            /flags:/ {
                for (i = 1; i <= NF; i++) {
                    if ($i == "ANSWER:") {
                        gsub(",", "", $(i+1))
                        print $(i+1)
                        exit
                    }
                }
            }
        ' <<< "$output"
    )

    QUERY_STATUS="${QUERY_STATUS:-UNKNOWN}"
    QUERY_ANSWERS="${QUERY_ANSWERS:-0}"
}

# Check whether a response contains an A RRset.
has_answer() {
    [[ "$1" == "NOERROR" && "$2" -gt 0 ]]
}

echo "  "
echo "## Check DNSSEC Trust Anchor"
echo "   Resolver: $RESOLVER"
echo "   Key Tag:  $KEY_TAG"
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
echo "  "

# Query a deliberately bogus DNSSEC name.
echo "// DNSSEC Validation Check"
echo "   dig @${RESOLVER} ${BOGUS_NAME} A +dnssec +time=3 +tries=1"

query_dns "$BOGUS_NAME"

BOGUS_STATUS="$QUERY_STATUS"
BOGUS_ANSWERS="$QUERY_ANSWERS"

echo "   Status:  $BOGUS_STATUS"
echo "   Answers: $BOGUS_ANSWERS"
echo "  "

# Query the positive trust anchor sentinel.
echo "// RFC 8509 is-ta Check"
echo "   dig @${RESOLVER} ${IS_TA_NAME} A +dnssec +time=3 +tries=1"

query_dns "$IS_TA_NAME"

IS_TA_STATUS="$QUERY_STATUS"
IS_TA_ANSWERS="$QUERY_ANSWERS"

echo "   Status:  $IS_TA_STATUS"
echo "   Answers: $IS_TA_ANSWERS"
echo "  "

# Query the negative trust anchor sentinel.
echo "// RFC 8509 not-ta Check"
echo "   dig @${RESOLVER} ${NOT_TA_NAME} A +dnssec +time=3 +tries=1"

query_dns "$NOT_TA_NAME"

NOT_TA_STATUS="$QUERY_STATUS"
NOT_TA_ANSWERS="$QUERY_ANSWERS"

echo "   Status:  $NOT_TA_STATUS"
echo "   Answers: $NOT_TA_ANSWERS"
echo "  "

# Classify the resolver behavior.
if [[ "$BOGUS_STATUS" == "SERVFAIL" ]] &&
   has_answer "$IS_TA_STATUS" "$IS_TA_ANSWERS" &&
   [[ "$NOT_TA_STATUS" == "SERVFAIL" ]]; then

    echo "## Result"
    echo "   DNSSEC Validation: PASS"
    echo "   RFC 8509:          SUPPORTED"
    echo "   Trust Anchor:      PASS"
    echo "  "
    exit 0

elif [[ "$BOGUS_STATUS" == "SERVFAIL" ]] &&
     [[ "$IS_TA_STATUS" == "SERVFAIL" ]] &&
     has_answer "$NOT_TA_STATUS" "$NOT_TA_ANSWERS"; then

    echo "## Result"
    echo "   DNSSEC Validation: PASS"
    echo "   RFC 8509:          SUPPORTED"
    echo "   Trust Anchor:      FAIL"
    echo "  "
    exit 1

elif [[ "$BOGUS_STATUS" == "SERVFAIL" ]] &&
     has_answer "$IS_TA_STATUS" "$IS_TA_ANSWERS" &&
     has_answer "$NOT_TA_STATUS" "$NOT_TA_ANSWERS"; then

    echo "## Result"
    echo "   DNSSEC Validation: PASS"
    echo "   RFC 8509:          NOT SUPPORTED"
    echo "   Trust Anchor:      INDETERMINATE"
    echo "  "
    exit 3

elif has_answer "$BOGUS_STATUS" "$BOGUS_ANSWERS" &&
     has_answer "$IS_TA_STATUS" "$IS_TA_ANSWERS" &&
     has_answer "$NOT_TA_STATUS" "$NOT_TA_ANSWERS"; then

    echo "## Result"
    echo "   DNSSEC Validation: FAIL"
    echo "   RFC 8509:          NOT APPLICABLE"
    echo "   Trust Anchor:      NOT CONFIRMED"
    echo "  "
    exit 1
fi

# Verify the underlying sentinel records without sentinel processing.
echo "// Test Infrastructure Check"
echo "   dig @${RESOLVER} ${IS_TA_NAME} A +dnssec +cd +time=3 +tries=1"

query_dns "$IS_TA_NAME" +cd

CD_IS_TA_STATUS="$QUERY_STATUS"
CD_IS_TA_ANSWERS="$QUERY_ANSWERS"

echo "   is-ta Status:  $CD_IS_TA_STATUS"
echo "   is-ta Answers: $CD_IS_TA_ANSWERS"

echo "   dig @${RESOLVER} ${NOT_TA_NAME} A +dnssec +cd +time=3 +tries=1"

query_dns "$NOT_TA_NAME" +cd

CD_NOT_TA_STATUS="$QUERY_STATUS"
CD_NOT_TA_ANSWERS="$QUERY_ANSWERS"

echo "   not-ta Status:  $CD_NOT_TA_STATUS"
echo "   not-ta Answers: $CD_NOT_TA_ANSWERS"
echo "  "

if ! has_answer "$CD_IS_TA_STATUS" "$CD_IS_TA_ANSWERS" ||
   ! has_answer "$CD_NOT_TA_STATUS" "$CD_NOT_TA_ANSWERS"; then

    echo "## Result"
    echo "   Test Infrastructure: FAIL"
    echo "   Trust Anchor:        INDETERMINATE"
    echo "  "
    exit 3
fi

echo "## Result"
echo "   Test Infrastructure: PASS"
echo "   RFC 8509:            INDETERMINATE"
echo "   Trust Anchor:        INDETERMINATE"
echo "  "
exit 3