#!/usr/bin/env bash
set -euo pipefail

command -v curl >/dev/null || { echo "missing curl" >&2; exit 2; }
command -v jq   >/dev/null || { echo "missing jq" >&2; exit 2; }

BASE_URL="https://dnsaudit.io"
SCAN_PATH="/api/v1/scan"
OUT_DIR="${OUT_DIR:-dnsaudit_reports}"

mkdir -p "$OUT_DIR"

read -r -s -p "# dnsaudit api key: " API_KEY; echo >&2
[[ -n "${API_KEY}" ]] || { echo "ERROR: empty API key" >&2; exit 2; }

read -r -p "# domain to scan: " DOMAIN
DOMAIN="$(echo "$DOMAIN" | sed 's/#.*$//' | xargs)"
[[ -n "${DOMAIN}" ]] || { echo "ERROR: empty domain" >&2; exit 2; }

AUTH_HEADER="x-api-key: ${API_KEY}"

scan_json="$(
  curl -fsS \
    -H "$AUTH_HEADER" \
    -H "Accept: application/json" \
    "${BASE_URL}${SCAN_PATH}?domain=${DOMAIN}"
)"

echo "$scan_json" | jq -e . >/dev/null 2>&1 || {
  echo "ERROR: scan endpoint did not return JSON. Preview:" >&2
  echo "$scan_json" | head -c 300 >&2
  exit 1
}

out_json="$OUT_DIR/${DOMAIN}.json"
echo "$scan_json" | jq . > "$out_json"

echo
echo "# Summary"
echo "$scan_json" | jq -r '
  "  Domain: " + (.domain // "n/a") + "\n" +
  "  Grade:  " + (.grade.grade // "n/a") + "\n" +
  "  Score:  " + ((.securityScore // .grade.score // "n/a") | tostring) + "\n" +
  "  Saved:  '"$out_json"'"
'

echo
echo "# Issues (grouped)"
echo "$scan_json" | jq -r '
  def arr(x): (x // []);
  def first_sentence(s):
    (s // "n/a")
    | split("\n")[0]
    | if index(".") != null then (split(".")[0] + ".") else . end;

  arr(.issues) as $all
  | if ($all|length)==0 then
      "  - none"
    else
      (["critical","warning","info","secure"] | map(
        . as $t
        | ($all | map(select((.type // "") == $t)) ) as $g
        | if ($g|length)>0 then
            "  \($t) (\($g|length))\n"
            + ($g | map("  - [" + (.type // "n/a") + "] " + (.recordType // "n/a") + ": " + first_sentence(.description)) | join("\n"))
          else empty end
      ) | join("\n\n"))
    end
'

echo