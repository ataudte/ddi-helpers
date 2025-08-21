#!/usr/bin/env python3

# This script parses a BIND named.conf DNS configuration file and extracts zone details,
# including zone name, type (master, slave, forward, stub), master/forwarder IPs, and dynamic update settings.
# It also captures any global forwarders defined in the options block.
# The results are written to a CSV file, with one row per zone, for easier documentation or migration.

import re
import csv
import sys
import os

def extract_ips_from_braces(text):
    if not text:
        return []
    results = []
    for item in re.split(r'[;\n]', text):
        item = item.strip()
        if not item or item in ('in', 'port'):
            continue
        # Remove 'port' and extra params
        item = item.split()[0]
        if item.endswith(';'):
            item = item[:-1]
        results.append(item)
    return results

def get_block_content(keyword, zone_block):
    pattern = re.compile(rf'{keyword}\s*\{{(.*?)\}};', re.DOTALL | re.IGNORECASE)
    match = pattern.search(zone_block)
    if match:
        return match.group(1)
    return ''

def get_zone_type(zone_block):
    match = re.search(r'type\s+([a-zA-Z]+);', zone_block)
    if match:
        return match.group(1).lower()
    return ""

def get_master_server_ips(zone_block, zone_type):
    if zone_type in ("slave", "secondary"):
        content = get_block_content("masters", zone_block)
        return ', '.join(extract_ips_from_braces(content))
    elif zone_type in ("forward", "stub"):
        content = get_block_content("forwarders", zone_block)
        return ', '.join(extract_ips_from_braces(content))
    elif zone_type in ("master", "primary"):
        content = get_block_content("allow-transfer", zone_block)
        return ', '.join(extract_ips_from_braces(content))
    return ''

def parse_zones_from_lines(lines):
    zones = []
    in_zone = False
    zone_name = None
    brace_level = 0
    current_block = []
    for line in lines:
        if not in_zone:
            m = re.match(r'\s*zone\s+"([^"]+)"', line)
            if m:
                in_zone = True
                zone_name = m.group(1)
                brace_level = line.count('{') - line.count('}')
                current_block = [line]
                if brace_level == 0 and '{' in line and '};' in line:
                    in_zone = False
                    zones.append((zone_name, '\n'.join(current_block)))
            continue
        else:
            current_block.append(line)
            brace_level += line.count('{')
            brace_level -= line.count('}')
            if brace_level == 0 and re.match(r'^\s*}\s*;?\s*$', line):
                in_zone = False
                zones.append((zone_name, '\n'.join(current_block)))
                current_block = []
    return zones

def get_replication_scope(zone_block):
    return ""

def get_is_shutdown(zone_block):
    return ""

def get_allow_update(zone_block):
    content = get_block_content("allow-update", zone_block)
    return ', '.join(extract_ips_from_braces(content)) if content else ""

def get_global_forwarders(config_lines):
    """Finds forwarders in the global options block (multi-line safe)."""
    in_options = False
    brace_level = 0
    options_block = []
    for line in config_lines:
        if not in_options:
            if re.match(r'^\s*options\s*{', line):
                in_options = True
                brace_level = line.count('{') - line.count('}')
                options_block = [line]
            continue
        else:
            options_block.append(line)
            brace_level += line.count('{')
            brace_level -= line.count('}')
            if brace_level == 0:
                # End of options block
                break

    options_text = '\n'.join(options_block)
    forwarders_content = get_block_content('forwarders', options_text)
    return ', '.join(extract_ips_from_braces(forwarders_content)) if forwarders_content else ""

def main():
    if len(sys.argv) < 2:
        print("Usage: python named2csv.py named.conf")
        sys.exit(1)

    conf_path = sys.argv[1]
    conf_dir = os.path.dirname(conf_path)
    conf_name = os.path.basename(conf_path)
    if len(sys.argv) > 2:
        output_path = sys.argv[2]
    else:
        if conf_name.lower().endswith('.conf'):
            csv_name = conf_name[:-5] + ".csv"
        else:
            csv_name = conf_name + ".csv"
        output_path = os.path.join(conf_dir, csv_name)


    with open(conf_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    global_forwarders = get_global_forwarders(lines)
    zones = parse_zones_from_lines(lines)

    fieldnames = [
        "XML File",
        "Server Name",
        "Global Forwarders",
        "Zone Name",
        "Zone Type",
        "ReplicationScope",
        "IsShutdown",
        "DynamicUpdate",
        "Zone-Type IPs"
    ]

    rows = []
    for zone_name, zone_block in zones:
        zone_type = get_zone_type(zone_block)
        replication_scope = get_replication_scope(zone_block)
        is_shutdown = get_is_shutdown(zone_block)
        allow_update = get_allow_update(zone_block)
        masters = get_master_server_ips(zone_block, zone_type)

        rows.append({
            "XML File": "",
            "Server Name": conf_name,
            "Global Forwarders": global_forwarders,
            "Zone Name": zone_name,
            "Zone Type": zone_type,
            "ReplicationScope": replication_scope,
            "IsShutdown": is_shutdown,
            "DynamicUpdate": allow_update,
            "Zone-Type IPs": masters
        })

    with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

if __name__ == '__main__':
    main()
