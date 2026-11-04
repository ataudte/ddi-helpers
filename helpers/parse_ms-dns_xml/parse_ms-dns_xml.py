import sys
import re
import pandas as pd
from lxml import etree

def extract_dns_data(xml_file):
    """Extracts DNS zones, Master Server IPs, and Global Forwarders from a Microsoft DNS Export XML file."""
    
    # Read the XML file
    with open(xml_file, "r", encoding="utf-16") as file:
        xml_content = file.read()

    # Extract Server Name
    server_name_match = re.search(r'<S N="ServerName">(.*?)</S>', xml_content)
    server_name = server_name_match.group(1) if server_name_match else "Unknown"

    # Extract Global Forwarders (ServerForwarder)
    forwarder_match = re.search(r'<Obj N="ServerForwarder" RefId="\d+">.*?<LST>(.*?)</LST>', xml_content, re.DOTALL)
    if forwarder_match:
        forwarder_ips = re.findall(r'<S>(\d+\.\d+\.\d+\.\d+)</S>', forwarder_match.group(1))
        global_forwarders = "; ".join(forwarder_ips)
    else:
        global_forwarders = "N/A"

    # Extract all zones (Primary, Secondary, Forwarder)
    zone_entries = []
    zone_raw_extracted = re.findall(r'(<ToString>DnsServer.*?Zone</ToString>.*?</Obj>)', xml_content, re.DOTALL)
    
    for zone_segment in zone_raw_extracted:
        # Extract Zone Name
        zone_name_match = re.search(r'<S N="ZoneName">(.*?)</S>', zone_segment)
        zone_name = zone_name_match.group(1) if zone_name_match else "Unknown"

        # Extract Zone Type
        zone_type_match = re.search(r'<S N="ZoneType">(.*?)</S>', zone_segment)
        zone_type = zone_type_match.group(1) if zone_type_match else "Unknown"

        # Extract MasterServers RefId
        master_ref_match = re.search(r'<Obj N="MasterServers" RefId="(\d+)"', zone_segment)
        master_ref_id = master_ref_match.group(1) if master_ref_match else "No RefId"

        # Extract ReplicationScope
        replication_scope_match = re.search(r'<S N="ReplicationScope">(.*?)</S>', zone_segment)
        replication_scope = replication_scope_match.group(1) if replication_scope_match else "N/A"

        # Extract IsShutdown
        is_shutdown_match = re.search(r'<B N="IsShutdown">(true|false)</B>', zone_segment)
        is_shutdown = is_shutdown_match.group(1) if is_shutdown_match else "N/A"

        # Extract DynamicUpdate
        dynamic_update_match = re.search(r'<S N="DynamicUpdate">(.*?)</S>', zone_segment)
        dynamic_update = dynamic_update_match.group(1) if dynamic_update_match else "N/A"

        # Store zone information
        zone_entries.append({
            "XML File": xml_file,
            "Server Name": server_name,
            "Global Forwarders": global_forwarders,
            "Zone Name": zone_name,
            "Zone Type": zone_type,
            "ReplicationScope": replication_scope,
            "IsShutdown": is_shutdown,
            "DynamicUpdate": dynamic_update,
            "MasterServers RefId": master_ref_id
        })
    
    # Extract all MasterServers and their IPs
    master_servers_map = {}
    master_servers_raw_extracted = re.findall(r'(<Obj N="MasterServers".*?</Obj>)', xml_content, re.DOTALL)

    for segment in master_servers_raw_extracted:
        # Extract RefId
        ref_id_match = re.search(r'<Obj N="MasterServers" RefId="(\d+)"', segment)
        ref_id = ref_id_match.group(1) if ref_id_match else None

        if ref_id:
            # Extract IPs from <LST><S> (direct listing of servers)
            master_ips = re.findall(r'<S>(\d+\.\d+\.\d+\.\d+)</S>', segment)

            # Extract IPs from <MS><S N="IPAddressToString"> (nested format)
            nested_ips = re.findall(r'<S N="IPAddressToString">(\d+\.\d+\.\d+\.\d+)</S>', segment)

            # Store in dictionary with RefId as key, ensuring unique values
            all_ips = sorted(set(master_ips + nested_ips))  # Sort to maintain order
            master_servers_map[ref_id] = "; ".join(all_ips) if all_ips else "N/A"
    
    # Assign Master Server IPs to zones
    for zone in zone_entries:
        if zone["Zone Type"] in ["Secondary", "Forwarder"]:
            zone["Master Server IPs"] = master_servers_map.get(zone["MasterServers RefId"], "N/A")
        else:
            zone["Master Server IPs"] = "N/A"

    # Convert to DataFrame
    df_zones = pd.DataFrame(zone_entries)

    # Save to CSV
    output_csv = xml_file.replace(".xml", "_parsed.csv")
    df_zones.to_csv(output_csv, index=False)

    print(f"Extraction completed! CSV saved as: {output_csv}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 parse_ms_dns_xml.py <dns_export.xml>")
        sys.exit(1)

    xml_file_path = sys.argv[1]
    extract_dns_data(xml_file_path)
