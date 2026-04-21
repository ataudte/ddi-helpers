#!/bin/bash

RNDC_PATH="/usr/local/nessy2/bin"
NAMED_CHECKZONE_PATH="/usr/local/nessy2/bin"
ZONE_PATH="/etc/namedb/zones/master"

ZONE_NAME="${1:?missing zone name}"
RECORD_NAME="${2:?missing record name}"

echo "rndc sync -clean"
"$RNDC_PATH/rndc" sync -clean

echo "named-checkzone -D -o -"
"$NAMED_CHECKZONE_PATH/named-checkzone" -D -o - "$ZONE_NAME" "$ZONE_PATH/$ZONE_NAME" 2>/dev/null |
{
  echo "grep -E '$RECORD_NAME'"
  grep -E "$RECORD_NAME"
}