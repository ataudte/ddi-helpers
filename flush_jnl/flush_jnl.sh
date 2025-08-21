#!/bin/bash

# This script starts a temporary BIND instance using the local named.conf,
# flushes .jnl journal files into .db zone files using `rndc sync -clean`,
# and shuts down the server cleanly. Supports debug and background modes.

set -e

# Configuration
DEBUG_MODE=false   # Set to true to run named in foreground debug mode

# Automatically set BASEDIR to current working directory
BASEDIR="$(pwd)"
DBSDIR="$BASEDIR/dbs"
RNDC_KEY="$BASEDIR/rndc.key"
RNDC_CONF="$BASEDIR/rndc.conf"
NAMED_CONF="$BASEDIR/named.conf"
PID_FILE="$BASEDIR/named.pid"

echo "==> Using BASEDIR: $BASEDIR"

# Step 1: Generate rndc.key if not present
echo "==> Step 1: Checking rndc.key"
if [ ! -f "$RNDC_KEY" ]; then
  echo "-- Generating rndc.key..."
  sudo /usr/local/sbin/rndc-confgen -a -c "$RNDC_KEY"
fi

# Step 2: Generate rndc.conf
echo "==> Step 2: Creating rndc.conf"
sudo awk 'BEGIN {
  print "options {\n  default-server 127.0.0.1;"
  print "  default-key \"rndc-key\";"
  print "  default-port 953;\n};"
} { print }' "$RNDC_KEY" > "$RNDC_CONF"

# Step 3: Patch named.conf
echo "==> Step 3: Patching named.conf"

cp "$NAMED_CONF" "$NAMED_CONF.bak"

if ! grep -q "include.*rndc.key" "$NAMED_CONF"; then
  echo "-- Adding include statement..."
  sed -i '' "1i\\
include \"$RNDC_KEY\";
" "$NAMED_CONF"
fi

if ! grep -q "controls" "$NAMED_CONF"; then
  echo "-- Adding controls block..."
  cat <<EOF >> "$NAMED_CONF"

controls {
    inet 127.0.0.1 port 953
    allow { 127.0.0.1; } keys { "rndc-key"; };
};
EOF
fi

echo "-- Removing dnssec-enable and dnssec-validation if present..."
sed -i '' '/dnssec-enable/d' "$NAMED_CONF"
sed -i '' '/dnssec-validation/d' "$NAMED_CONF"

echo "-- Updating directory path in named.conf to: $DBSDIR"
sed -i '' "s|directory \".*\";|directory \"$DBSDIR\";|" "$NAMED_CONF"

# Step 4: Start named
echo "==> Step 4: Starting named"
if [ "$DEBUG_MODE" = true ]; then
  echo "-- Starting in foreground debug mode"
  sudo /usr/local/opt/bind/sbin/named -c "$NAMED_CONF" -g -d 1 &
  NAMED_PID=$!
else
  echo "-- Starting in background (no debug)"
  sudo /usr/local/opt/bind/sbin/named -c "$NAMED_CONF"
  sleep 2
  NAMED_PID=$(pgrep -n -f "named.*$NAMED_CONF" || true)
fi

# Step 5: Check if named is running
echo "==> Step 5: Verifying named is running"
if [ -n "$NAMED_PID" ] && ps -p "$NAMED_PID" > /dev/null; then
  echo "-- named is running (PID: $NAMED_PID)"
else
  echo "ERROR: named failed to start"
  exit 1
fi

# Step 6: Check rndc connection
echo "==> Step 6: Checking rndc status"
if sudo /usr/local/opt/bind/sbin/rndc -c "$RNDC_CONF" status; then
  echo "-- rndc is connected successfully"
else
  echo "ERROR: rndc could not connect to named"
  sudo kill "$NAMED_PID" 2>/dev/null || true
  exit 1
fi

# Step 7: Sync all zones
echo "==> Step 7: Flushing journal files"
sudo /usr/local/opt/bind/sbin/rndc -c "$RNDC_CONF" sync -clean

# Step 8: Stop named
echo "==> Step 8: Stopping named"
sudo kill "$NAMED_PID"
sleep 1

echo "==> Done: Journals flushed and named stopped cleanly."
