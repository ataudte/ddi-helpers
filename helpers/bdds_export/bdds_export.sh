#!/bin/bash

# Collects DNS/DHCP data from local server and archives it
# - Normalizes named.conf and collects zone files
# - Copies dhcpd.conf with hostname prefix
# - Output: /tmp/<hostname>_ddi-export_<timestamp>.tar.gz

# Variables
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
HOSTNAME=$(hostname)
EXPORT_DIR="/tmp/${HOSTNAME}_ddi-export_${TIMESTAMP}"
EXPORT_DBS="${EXPORT_DIR}/dbs"
EXPORT_ARCHIVE="${EXPORT_DIR}.tar.gz"
DNS_DIR="/replicated/jail/named/etc"
ZONE_DIR="/replicated/jail/named/var/dns-config/dbs"
CHROOT_BASE="/replicated/jail/named"
DHCP_CONF="/replicated/etc/dhcpd.conf"
NAMED_CONF="${DNS_DIR}/named.conf"
NORMALIZED_CONF="named_${HOSTNAME}.conf"
HOST_DHCP_CONF="dhcpd_${HOSTNAME}.conf"

# Create export directory
mkdir -p "$EXPORT_DIR"

echo "# DDI Export of $HOSTNAME into $EXPORT_DIR"
echo "  - $NAMED_CONF"
echo "  - $ZONE_DIR"
echo "  - $DHCP_CONF"

# Export DNS Configuration
echo "# Checking DNS Config"

if [[ -s "$NAMED_CONF" ]]; then
    echo "[ ] Syncing Journal Files"
    rndc sync -clean

    echo "[ ] Normalizing named.conf"
    named-checkconf -t "$CHROOT_BASE" -p > "${EXPORT_DIR}/${NORMALIZED_CONF}"

    if [[ -d "$ZONE_DIR" ]]; then
        echo "[ ] Copying Zone Files"
        mkdir -p "$EXPORT_DBS"
        cp -r "$ZONE_DIR"/* "$EXPORT_DBS"
    else
        echo "[x] Zone Directory $ZONE_DIR not found"
    fi
else
    echo "[x] named.conf is missing or empty"
fi

# Export DHCP Configuration
echo "# Checking DHCP Config"

if [[ -s "$DHCP_CONF" ]]; then
    echo "[ ] Copying dhcpd.conf"
    cp "$DHCP_CONF" "${EXPORT_DIR}/${HOST_DHCP_CONF}"
else
    echo "[x] dhcpd.conf is missing or empty"
fi

# Create tar.gz archive
echo "[ ] Creating Archive"
tar -czf "$EXPORT_ARCHIVE" -C /tmp "$(basename "$EXPORT_DIR")"

# Cleanup
rm -rf "$EXPORT_DIR"

# Verify archive creation
if [[ -f "$EXPORT_ARCHIVE" ]]; then
    echo "[ ] Export stored in $EXPORT_ARCHIVE"
else
    echo "[x] Export failed"
fi
