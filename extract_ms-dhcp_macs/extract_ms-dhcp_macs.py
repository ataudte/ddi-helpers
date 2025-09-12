#!/usr/bin/env python3

# This script extracts MAC-to-IP mappings from a Microsoft DHCP Server XML export.  
# It generates a complete list of all MACs and their associated IPs and a filtered list showing only MACs with multiple IPs.

import os
import sys
import csv
import xml.etree.ElementTree as ET
from collections import defaultdict

def normalize_mac(mac_str):
    """Convert MAC format like 58-38-79-95-ff-d9 to 58387995ffd9"""
    return mac_str.strip().lower().replace("-", "").replace(":", "")

def extract_mac_ip_map(xml_path):
    tree = ET.parse(xml_path)
    root = tree.getroot()
    mac_to_ips = defaultdict(list)

    for reservation in root.findall(".//Reservation"):
        mac_raw = reservation.findtext("ClientId")
        ip = reservation.findtext("IPAddress")

        if mac_raw and ip:
            mac = normalize_mac(mac_raw)
            mac_to_ips[mac].append(ip)

    return mac_to_ips

def write_csv(mac_to_ips, output_path):
    sorted_entries = sorted(mac_to_ips.items())  # Sort by MAC address
    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        for mac, ips in sorted_entries:
            writer.writerow([mac, "|".join(ips)])
    return len(sorted_entries)

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python extract_ms-dhcp_macs.py <dhcp_export.xml>")
        sys.exit(1)

    xml_file = sys.argv[1]
    base_path = os.path.splitext(xml_file)[0]

    # Extract mappings
    mac_map = extract_mac_ip_map(xml_file)

    # Write all MACs, sorted
    all_csv = base_path + "_MACs-all.csv"
    lines_all = write_csv(mac_map, all_csv)

    # Write only multi-IP MACs, sorted
    multi_map = {mac: ips for mac, ips in mac_map.items() if len(ips) > 1}
    multi_csv = base_path + "_MACs-multi.csv"
    lines_multi = write_csv(multi_map, multi_csv)

    # Print summary
    print(f"[+] {lines_all} MACs written to {all_csv}")
    print(f"[+] {lines_multi} MACs with multiple IPs written to {multi_csv}")
