#!/bin/bash

# This script compares DNS zone file variants by prefix or suffix.
# It collects matching files (excluding reverse zones), removes duplicates,
# cleans MS DNS artifacts, canonicalizes them using named-checkzone,
# and compares them after normalizing (ignoring SOA and TTL).
# Differences are logged, and non-identical variants are saved for review.

set -e

function sanitize_zone() {
  awk '
    # Skip SOA records
    tolower($3) == "in" && tolower($4) == "soa" { next }

    # Remove TTL if second field is numeric
    NF >= 5 && $2 ~ /^[0-9]+$/ {
      printf "%s\t%s\t%s\t", $1, $3, $4
      for (i = 5; i <= NF; i++) printf "%s ", $i
      printf "\n"
      next
    }

    { print }
  ' "$1" | tr '[:upper:]' '[:lower:]' | sort
}

function cleanms() {
  msfile="$1"
  if egrep -q "\[A.*:[0-9]{7}\]*" "$msfile"; then
    echo "[ ] clean-up of MS-DNS TIME_STAMPs in zone file ${msfile##*/}"
    sed -E "s/\[A.*:[0-9]{7}\]*//" "$msfile" > "${msfile}.tmp" \
      && cp "$msfile" "${msfile}_$(date '+%Y%m%d-%H%M%S').save" \
      && mv "${msfile}.tmp" "$msfile"
  fi
  if grep -qE '^[^;]*WINSR' "$msfile"; then
    echo "[ ] Removing WINSR records from ${msfile##*/}"
    sed -i.bak '/^[^;]*WINSR/d' "$msfile"
  fi
  if grep -q $'\r' "$msfile"; then
    echo "[ ] Converting DOS line endings to Unix in file $(basename "$msfile")"
    dos2unix "$msfile" 2>/dev/null
  fi
}

function canzonefile() {
  suffix="$1"
  zfile="$2"
  zname="$3"
  outdir="${4:-$(dirname "$zfile")}"
  canfile="${outdir}/$(basename "$zfile")_${suffix}"

  cleanms "$zfile"

  # Inject $ORIGIN if not present and file begins with '@' or SOA
  if ! grep -qi '^\$ORIGIN' "$zfile" && grep -qE '^\s*@\s|IN\s+SOA' "$zfile"; then
    echo "[ ] Injecting \$ORIGIN $zname in file ${zfile##*/}"
    tmpfile="$(mktemp)"
    echo "\$ORIGIN $zname." > "$tmpfile"
    cat "$zfile" >> "$tmpfile"
    cp "$zfile" "${zfile}_$(date '+%Y%m%d-%H%M%S').bak"
    mv "$tmpfile" "$zfile"
  fi

  istext=$( named-checkzone -f text ${zname} ${zfile} | tail -1 )
  israw=$( named-checkzone -f raw ${zname} ${zfile} | tail -1 )
  if [ "$istext" == "OK" ]; then named-checkzone -f text -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  elif [ "$israw" == "OK" ]; then named-checkzone -f raw -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  else
    echo "[x] named-checkzone crashed or failed on file '$zfile' with zone name '$zname'" | tee -a "$LOG_ERROR"
    continue
  fi

  if [[ ! -f "$canfile" ]]; then
    echo "[x] Output file not created for '$zfile'" | tee -a "$LOG_ERROR"
    continue
  fi
}

# Parameters
SEARCH_PATH="$1"
MATCH_TYPE="$2"

if [[ -z "$SEARCH_PATH" || -z "$MATCH_TYPE" ]]; then
    echo "[x] Usage: $0 <path> prefix=<prefix> | suffix=<suffix>"
    exit 1
fi

# Start Counter
SECONDS=0

# Directories
WORK_DIR="${SEARCH_PATH}/_working"
ORIG_DIR="$WORK_DIR/original"
CANO_DIR="$WORK_DIR/canon"
VARI_DIR="$WORK_DIR/variants"
mkdir -p "$WORK_DIR" "$ORIG_DIR" "$CANO_DIR" "$VARI_DIR"

# Log Files
SCRIPT_NAME=$(basename "$0" | sed 's/\.sh$//')
TIME_STAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="$WORK_DIR/${SCRIPT_NAME}_$TIME_STAMP.log"
LOG_ERROR="$WORK_DIR/${SCRIPT_NAME}_$TIME_STAMP.errors"
LOG_RESULT="$WORK_DIR/${SCRIPT_NAME}_$TIME_STAMP.results"
# Log stdout to LOG_FILE
exec > >(tee -a "$LOG_FILE")
# Log stderr to LOG_FILE and LOG_ERROR
exec 2> >(tee -a "$LOG_FILE" | tee -a "$LOG_ERROR" >&2)

if [[ "$MATCH_TYPE" == prefix=* ]]; then
    PREFIX="${MATCH_TYPE#prefix=}"
    FIND_EXPR="-name '${PREFIX}*'"
elif [[ "$MATCH_TYPE" == suffix=* ]]; then
    SUFFIX="${MATCH_TYPE#suffix=}"
    FIND_EXPR="-name '*.${SUFFIX}'"
else
    echo "[x] Invalid match type: use prefix= or suffix="  | tee -a "$LOG_ERROR"
    exit 1
fi

echo "### Collecting matching zone files..."
eval find "\"$SEARCH_PATH\"" -type f $FIND_EXPR | while read -r file; do

    # Skip certain file patterns
    if [[ "$file" == *"in-addr.arpa"* || "$file" == *"ip6.arpa"* || "$file" == *"TrustAnchor"* ]]; then
        continue
    fi
    echo "[ ] Found: $file"

    # Check for duplicate content before copying
    hash=$(sha256sum "$file" | awk '{print $1}')
    duplicate=0
    for existing in "$ORIG_DIR"/*; do
        [[ -f "$existing" ]] || continue
        exthash=$(sha256sum "$existing" | awk '{print $1}')
        if [[ "$exthash" == "$hash" ]]; then
            echo "[ ] Skipping duplicate file (same content): $file"
            duplicate=1
            break
        fi
    done
    if [[ "$duplicate" -eq 1 ]]; then
        continue
    fi

    # Generate a unique destination name
    BASENAME=$(basename "$file")
    i=1
    while true; do
        DEST="$ORIG_DIR/${BASENAME}_$i"
        [[ ! -e "$DEST" ]] && break
        ((i++))
    done

    echo "[ ] Copying: $DEST"
    cp "$file" "$DEST"

done

echo "### Canonicalizing zone files..."
cd "$ORIG_DIR"
for f in $(ls | grep -vE '(_canon$|\.log$|_errors_|_variants_)'); do
  base=$(echo "$f" | sed -E 's/_[0-9]+$//')
  zname=$(echo "$base" | sed 's/^db\.//')
  canzonefile "canon" "$f" "$zname" "$CANO_DIR"
done

echo "### Comparing canonical zone files..."
cd "$CANO_DIR"

tmp_grouping=$(mktemp)

# Generate base name safely
for f in *_canon; do
  [[ -f "$f" ]] || continue
  base=$(echo "$f" | sed -E 's/_[0-9]+_canon$//')
  echo "$base $f" >> "$tmp_grouping"
done

cut -d' ' -f1 "$tmp_grouping" | sort | uniq | while read -r base; do
  MATCHES=( $(grep "^$base " "$tmp_grouping" | cut -d' ' -f2) )

  if (( ${#MATCHES[@]} > 1 )); then
    echo "[ ] Processing canonical duplicates for zone: $base (${#MATCHES[@]} variants)"

    identical=1
    tmp1=$(mktemp)
    tmp2=$(mktemp)

    sanitize_zone "${MATCHES[0]}" | sort > "$tmp1"

    for ((i=1; i<${#MATCHES[@]}; i++)); do
      sanitize_zone "${MATCHES[i]}" | sort > "$tmp2"
      if ! diff -q "$tmp1" "$tmp2" > /dev/null; then
        identical=0
        echo "[!] Difference detected between ${MATCHES[0]} and ${MATCHES[i]}" | tee -a "$LOG_RESULT"
        break
      fi
    done

    rm -f "$tmp1" "$tmp2"

    if [[ $identical -eq 1 ]]; then
      echo "[ ] All canonical variants of $base are identical (ignoring SOA + TTL)"
      keep="${MATCHES[0]}"
      for f in "${MATCHES[@]}"; do
        [[ "$f" != "$keep" ]] && rm -f "$f"
      done
    else
      echo "[!] Canonical variants of $base differ. Keeping ${#MATCHES[@]} variants for review." | tee -a "$LOG_RESULT"
      for f in "${MATCHES[@]}"; do
        cp "$f" "$VARI_DIR/"
      done
    fi
  fi
done

rm -f "$tmp_grouping"


# Log singleton canonical files that were not compared
echo "### Checking for unpaired canonical files..."
for f in $(ls *_canon); do
  base=$(echo "$f" | sed -E 's/(_[0-9]+)?_canon$//')
  match_count=$(ls "${base}"*_canon 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$match_count" -eq 1 ]]; then
    echo "[ ] Only one variant found for zone $base (file: $f)"
  fi
done

# Done
duration=$SECONDS
echo "[ ] Canonicalization and Comparison took $(($duration / 60))min. and $(($duration % 60))sec."
if [[ "$MATCH_TYPE" == prefix=* ]]; then
  echo "[ ] Prefix:     ${MATCH_TYPE#prefix=}"
else
  echo "[ ] Suffix:     ${MATCH_TYPE#suffix=}"
fi
echo "[ ] Originals:  $ORIG_DIR"
echo "[ ] Canonicals: $CANO_DIR"
echo "[ ] Variants:   $VARI_DIR"
echo "[ ] Log:        $LOG_FILE"
echo "[ ] Errors:     $LOG_ERROR"
echo "[ ] Results:    $LOG_RESULT"
