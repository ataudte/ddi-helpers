#!/usr/bin/env bash

# Check whether a recursive DNS resolver trusts a given
# root DNSSEC trust anchor using RFC 8509.
#
# Usage:
#   ./check_ksk.sh [-v] <resolver-ip> <key-tag>
#
# Exit codes:
#   0  Trust anchor confirmed
#   1  Trust anchor not confirmed
#   2  Usage, input, or dependency error
#   3  Indeterminate or no determinate sentinel result

set -u

VERBOSE=0
POSITIONAL=()

for arg in "$@"; do
    case "$arg" in
        -v)
            VERBOSE=1
            ;;
        *)
            POSITIONAL+=("$arg")
            ;;
    esac
done

if (( ${#POSITIONAL[@]} != 2 )); then
    echo "Usage: $0 [-v] <resolver-ip> <key-tag>"
    exit 2
fi

RESOLVER="${POSITIONAL[0]}"
KEY_TAG="${POSITIONAL[1]}"

CANARY_ZONES=(
    "d2a1n1.rootcanary.net."
    "d2a3n1.rootcanary.net."
    "d2a5n1.rootcanary.net."
    "d2a6n3.rootcanary.net."
    "d2a7n3.rootcanary.net."
    "d2a8n3.rootcanary.net."
    "d2a10n3.rootcanary.net."
    "d2a12n3.rootcanary.net."
    "d2a13n3.rootcanary.net."
    "d2a14n3.rootcanary.net."
    "d2a15n3.rootcanary.net."
    "d2a16n3.rootcanary.net."
    "d3a1n1.rootcanary.net."
    "d3a3n1.rootcanary.net."
    "d3a5n1.rootcanary.net."
    "d3a6n3.rootcanary.net."
    "d3a7n3.rootcanary.net."
    "d3a8n3.rootcanary.net."
    "d3a10n3.rootcanary.net."
    "d3a12n3.rootcanary.net."
    "d3a13n3.rootcanary.net."
    "d3a14n3.rootcanary.net."
    "d3a15n3.rootcanary.net."
    "d3a16n3.rootcanary.net."
    "d4a1n1.rootcanary.net."
    "d4a3n1.rootcanary.net."
    "d4a5n1.rootcanary.net."
    "d4a6n3.rootcanary.net."
    "d4a7n3.rootcanary.net."
    "d4a8n3.rootcanary.net."
    "d4a10n3.rootcanary.net."
    "d4a12n3.rootcanary.net."
    "d4a13n3.rootcanary.net."
    "d4a14n3.rootcanary.net."
    "d4a15n3.rootcanary.net."
    "d4a16n3.rootcanary.net."
)

for cmd in dig python3 awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd Is Required"
        exit 2
    fi
done

if ! python3 -c \
    'import ipaddress, sys; ipaddress.ip_address(sys.argv[1])' \
    "$RESOLVER" 2>/dev/null; then
    echo "Error: Resolver Must Be A Valid IPv4 Or IPv6 Address"
    exit 2
fi

if ! [[ "$KEY_TAG" =~ ^[0-9]+$ ]] || (( KEY_TAG < 0 || KEY_TAG > 65535 )); then
    echo "Error: Key Tag Must Be An Integer Between 0 And 65535"
    exit 2
fi

printf -v KEY_TAG_PADDED "%05d" "$KEY_TAG"

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

has_answer() {
    [[ "$1" == "NOERROR" && "$2" -gt 0 ]]
}

progress_bar() {
    local current="$1"
    local total="$2"
    local width=40
    local filled=$(( current * width / total ))
    local empty=$(( width - filled ))
    local bar=""
    local spaces=""

    printf -v bar "%${filled}s"
    bar="${bar// /#}"

    printf -v spaces "%${empty}s"

    printf "\rTesting Canary Zones: [%-40s] %3d%% (%d/%d)" \
        "${bar}${spaces}" \
        $(( current * 100 / total )) \
        "$current" \
        "$total"
}

declare -a RESULTS
declare -a DETAILS

TOTAL=${#CANARY_ZONES[@]}
DNSSEC_ELIGIBLE=0
BASELINE_FAILED=0
UNREACHABLE=0
TRUSTED=0
NOT_TRUSTED=0
SENTINEL_NOT_OBSERVED=0
INDETERMINATE=0

echo
echo "## Check DNSSEC Trust Anchor"
echo "   Resolver:     $RESOLVER"
echo "   Key Tag:      $KEY_TAG"
echo "   Canary Zones: $TOTAL"
echo "   Verbose:      $([[ "$VERBOSE" -eq 1 ]] && echo "Enabled" || echo "Disabled")"
echo

echo "// DNS Resolution Check"
echo "   dig @${RESOLVER} . SOA +time=3 +tries=1 +short"

if ! dig @"$RESOLVER" . SOA +time=3 +tries=1 +short >/dev/null 2>&1; then
    echo "   DNS Resolution: FAIL"
    echo
    exit 1
fi

echo "   DNS Resolution: PASS"
echo

index=0

for zone in "${CANARY_ZONES[@]}"; do
    secure_name="secure.${zone}"
    bogus_name="bogus.${zone}"
    is_ta_name="root-key-sentinel-is-ta-${KEY_TAG_PADDED}.${zone}"
    not_ta_name="root-key-sentinel-not-ta-${KEY_TAG_PADDED}.${zone}"

    query_dns "$secure_name"
    secure_status="$QUERY_STATUS"
    secure_answers="$QUERY_ANSWERS"

    query_dns "$bogus_name"
    bogus_status="$QUERY_STATUS"
    bogus_answers="$QUERY_ANSWERS"

    if [[ "$secure_status" == "ERROR" || "$bogus_status" == "ERROR" ]]; then
        result="ERROR"
        detail="Secure=${secure_status}/${secure_answers}, Bogus=${bogus_status}/${bogus_answers}"
        ((UNREACHABLE+=1))
    elif ! has_answer "$secure_status" "$secure_answers" || [[ "$bogus_status" != "SERVFAIL" ]]; then
        result="BASELINE_FAILED"
        detail="Secure=${secure_status}/${secure_answers}, Bogus=${bogus_status}/${bogus_answers}"
        ((BASELINE_FAILED+=1))
    else
        ((DNSSEC_ELIGIBLE+=1))

        query_dns "$is_ta_name"
        is_ta_status="$QUERY_STATUS"
        is_ta_answers="$QUERY_ANSWERS"

        query_dns "$not_ta_name"
        not_ta_status="$QUERY_STATUS"
        not_ta_answers="$QUERY_ANSWERS"

        detail="Secure=${secure_status}/${secure_answers}, Bogus=${bogus_status}/${bogus_answers}, Is-Ta=${is_ta_status}/${is_ta_answers}, Not-Ta=${not_ta_status}/${not_ta_answers}"

        if has_answer "$is_ta_status" "$is_ta_answers" && [[ "$not_ta_status" == "SERVFAIL" ]]; then
            result="TRUSTED"
            ((TRUSTED+=1))
        elif [[ "$is_ta_status" == "SERVFAIL" ]] && has_answer "$not_ta_status" "$not_ta_answers"; then
            result="NOT_TRUSTED"
            ((NOT_TRUSTED+=1))
        elif has_answer "$is_ta_status" "$is_ta_answers" && has_answer "$not_ta_status" "$not_ta_answers"; then
            result="SENTINEL_NOT_OBSERVED"
            ((SENTINEL_NOT_OBSERVED+=1))
        else
            result="INDETERMINATE"
            ((INDETERMINATE+=1))
        fi
    fi

    RESULTS[index]="$result"
    DETAILS[index]="$detail"

    ((index+=1))
    progress_bar "$index" "$TOTAL"
done

printf "\n"

if (( VERBOSE == 1 )); then
    echo
    echo "// Canary Zone Results"
    printf "   %-30s %-16s\n" "Zone" "Result"
    printf "   %-30s %-16s\n" "------------------------------" "----------------"
    for i in "${!CANARY_ZONES[@]}"; do
        printf "   %-30s %-16s\n" "${CANARY_ZONES[$i]}" "${RESULTS[$i]}"
    done
fi

SUPPORTED=$(( TRUSTED + NOT_TRUSTED ))
DETERMINATE=$SUPPORTED
MAJORITY=0

if (( DETERMINATE > 0 )); then
    if (( TRUSTED >= NOT_TRUSTED )); then
        MAJORITY="$TRUSTED"
    else
        MAJORITY="$NOT_TRUSTED"
    fi
    TRUST_CONSENSUS=$(( MAJORITY * 100 / DETERMINATE ))
else
    TRUST_CONSENSUS=0
fi

if (( DNSSEC_ELIGIBLE > 0 )); then
    TEST_COVERAGE=$(( DETERMINATE * 100 / DNSSEC_ELIGIBLE ))
else
    TEST_COVERAGE=0
fi

echo
echo "// Candidate Filtering"
printf "   %-24s %d\n" "Total Canary Zones:" "$TOTAL"
printf "   %-24s %d\n" "DNSSEC Eligible:" "$DNSSEC_ELIGIBLE"
printf "   %-24s %d\n" "Baseline Failed:" "$BASELINE_FAILED"
printf "   %-24s %d\n" "Unreachable/Error:" "$UNREACHABLE"

echo
echo "// RFC 8509 Sentinel Results"
printf "   %-28s %d\n" "Determinate Tests:" "$DETERMINATE"
printf "   %-28s %d\n" "Trusted:" "$TRUSTED"
printf "   %-28s %d\n" "Not Trusted:" "$NOT_TRUSTED"
printf "   %-28s %d\n" "Sentinel Not Observed:" "$SENTINEL_NOT_OBSERVED"
printf "   %-28s %d\n" "Indeterminate:" "$INDETERMINATE"

echo
echo "## Result"

if (( DETERMINATE == 0 )); then
    OVERALL_RESULT="INDETERMINATE"
    EXIT_CODE=3
elif (( TRUSTED > NOT_TRUSTED )); then
    OVERALL_RESULT="TRUSTED"
    EXIT_CODE=0
elif (( NOT_TRUSTED > TRUSTED )); then
    OVERALL_RESULT="NOT_TRUSTED"
    EXIT_CODE=1
else
    OVERALL_RESULT="INDETERMINATE"
    EXIT_CODE=3
fi

printf "   %-20s %s\n" "Overall Result:" "$OVERALL_RESULT"
printf "   %-20s %d%% (%d/%d)\n" "Trust Consensus:" "$TRUST_CONSENSUS" "$MAJORITY" "$DETERMINATE"
printf "   %-20s %d%% (%d/%d)\n" "Test Coverage:" "$TEST_COVERAGE" "$DETERMINATE" "$DNSSEC_ELIGIBLE"

if (( VERBOSE == 1 )); then
    echo
    echo "// Excluded Or Divergent Zones"

    printed=0

    for i in "${!CANARY_ZONES[@]}"; do
        result="${RESULTS[$i]}"

        if [[ "$result" == "BASELINE_FAILED" ||
              "$result" == "ERROR" ||
              "$result" == "SENTINEL_NOT_OBSERVED" ||
              "$result" == "INDETERMINATE" ||
              ( "$OVERALL_RESULT" == "TRUSTED" && "$result" == "NOT_TRUSTED" ) ||
              ( "$OVERALL_RESULT" == "NOT_TRUSTED" && "$result" == "TRUSTED" ) ]]; then

            echo "   ${CANARY_ZONES[$i]}"
            echo "      Result:  $result"
            echo "      Details: ${DETAILS[$i]}"
            printed=1
        fi
    done

    if (( printed == 0 )); then
        echo "   None"
    fi
fi

echo
exit "$EXIT_CODE"
