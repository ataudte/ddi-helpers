#!/bin/bash

# Set the path to your DHCP leases file here
LEASES_FILE="/replicated/var/state/dhcp/dhcpd.leases"

# Check if the leases file exists
if [[ ! -f "$LEASES_FILE" ]]; then
  echo "Leases file not found at: $LEASES_FILE"
  exit 1
fi

# Count active leases (unique IPs)
active_leases=$(awk -v file="$LEASES_FILE" '
  BEGIN { RS=""; FS="\n" }
  {
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^lease /) ip = $i;
      if ($i ~ /binding state active;/) {
        match(ip, /lease ([0-9.]+)/, m);
        print m[1];
      }
    }
  }
' "$LEASES_FILE" | sort -u | wc -l)

# Count active clients (unique MACs)
active_clients=$(awk -v file="$LEASES_FILE" '
  BEGIN { RS=""; FS="\n" }
  {
    ip = ""; mac = "";
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^lease /) ip = $i;
      if ($i ~ /hardware ethernet/) mac = $i;
      if ($i ~ /binding state active;/) {
        match(mac, /hardware ethernet ([0-9a-f:]+)/, m);
        if (m[1] != "") print m[1];
      }
    }
  }
' "$LEASES_FILE" | sort -u | wc -l)

# Output the results
echo "Active Leases (Unique IPs): $active_leases"
echo "Active Clients (Unique MACs): $active_clients"
