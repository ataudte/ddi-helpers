#!/bin/bash

# This script extracts *_dns-config.xml files from ZIP archives in a given directory,
# then uses an inline Python script to parse the XML and extract zone-related data,
# including server name, global forwarders, zone type, and replication details.
# The output is a merged CSV file containing a summary of all parsed zones.
# Usage: ./dns_zip2csv.sh <directory-with-zip-files>

if [ -z "$1" ]; then
    echo "Usage: $0 <directory-with-zip-files>"
    exit 1
fi

TARGET_DIR="$1"
OUTPUT_DIR="$TARGET_DIR/dns_xml_files"
MERGED_CSV="$TARGET_DIR/dns_zones_merged.csv"

mkdir -p "$OUTPUT_DIR"

# Step 1: Extract all *_dns-config.xml from zip files
echo "Extracting XML files..."
shopt -s nullglob nocaseglob
found_zip=0
for zip in "$TARGET_DIR"/*.[Zz][Ii][Pp]; do
    [ -e "$zip" ] || continue
    echo "Processing: $zip"
    unzip -j "$zip" "*_dns-config.xml" -d "$OUTPUT_DIR"
    found_zip=1
done
shopt -u nocaseglob

if [ $found_zip -eq 0 ]; then
    echo "No ZIP files found in $TARGET_DIR"
    exit 1
fi


# Step 2: Run inline Python script to parse & merge
echo "Parsing XML and generating CSV..."
python3 - <<EOF
import os
import re
import csv

xml_dir = "$OUTPUT_DIR"
csv_file = "$MERGED_CSV"

def parse_xml(path):
    with open(path, "r", encoding="utf-16") as f:
        content = f.read()

    # Server Name
    server_name = re.search(r'<S N="ServerName">(.*?)</S>', content)
    server_name = server_name.group(1) if server_name else "Unknown"

    # Global Forwarders
    fwd_match = re.search(r'<Obj N="ServerForwarder".*?<LST>(.*?)</LST>', content, re.DOTALL)
    fwd_ips = re.findall(r'<S>(\\d+\\.\\d+\\.\\d+\\.\\d+)</S>', fwd_match.group(1)) if fwd_match else []
    forwarders = "; ".join(fwd_ips) if fwd_ips else "N/A"

    # Master Servers
    master_map = {}
    for seg in re.findall(r'(<Obj N="MasterServers".*?</Obj>)', content, re.DOTALL):
        refid = re.search(r'RefId="(\\d+)"', seg)
        if not refid:
            continue
        ips = re.findall(r'<S>(\\d+\\.\\d+\\.\\d+\\.\\d+)</S>', seg)
        ips += re.findall(r'<S N="IPAddressToString">(\\d+\\.\\d+\\.\\d+\\.\\d+)</S>', seg)
        master_map[refid.group(1)] = "; ".join(sorted(set(ips))) if ips else "N/A"

    rows = []
    for zone in re.findall(r'(<ToString>DnsServer.*?Zone</ToString>.*?</Obj>)', content, re.DOTALL):
        name = re.search(r'<S N="ZoneName">(.*?)</S>', zone)
        ztype = re.search(r'<S N="ZoneType">(.*?)</S>', zone)
        refid = re.search(r'<Obj N="MasterServers" RefId="(\\d+)"', zone)
        repl = re.search(r'<S N="ReplicationScope">(.*?)</S>', zone)
        shut = re.search(r'<B N="IsShutdown">(true|false)</B>', zone)
        dyn = re.search(r'<S N="DynamicUpdate">(.*?)</S>', zone)

        row = {
            "XML File": os.path.basename(path),
            "Server Name": server_name,
            "Global Forwarders": forwarders,
            "Zone Name": name.group(1) if name else "Unknown",
            "Zone Type": ztype.group(1) if ztype else "Unknown",
            "ReplicationScope": repl.group(1) if repl else "N/A",
            "IsShutdown": shut.group(1) if shut else "N/A",
            "DynamicUpdate": dyn.group(1) if dyn else "N/A",
            "Master Server IPs": "N/A"
        }

        if row["Zone Type"] in ["Secondary", "Forwarder"] and refid:
            row["Master Server IPs"] = master_map.get(refid.group(1), "N/A")

        rows.append(row)

    return rows

all_rows = []
for file in os.listdir(xml_dir):
    if file.endswith(".xml"):
        try:
            all_rows.extend(parse_xml(os.path.join(xml_dir, file)))
        except Exception as e:
            print(f"Error parsing {file}: {e}", file=sys.stderr)

headers = [
    "XML File", "Server Name", "Global Forwarders", "Zone Name",
    "Zone Type", "ReplicationScope", "IsShutdown",
    "DynamicUpdate", "Master Server IPs"
]

with open(csv_file, "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=headers)
    writer.writeheader()
    writer.writerows(all_rows)

print(f"CSV written to: {csv_file}")
EOF
