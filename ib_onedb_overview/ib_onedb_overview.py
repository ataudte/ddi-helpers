#!/usr/bin/env python3

# This script parses an Infoblox OneDB XML export (onedb.xml) and generates
# CSV files summarizing DNS zones (incl. forwarders, AD integration, and dynamic DNS settings)
# and DHCP configuration (networks, ranges, reservations, and custom DHCP options).  
# Zones are grouped and optionally split by DNS view.


import argparse, os, zipfile, sys, csv, json, re
from pathlib import Path
from xml.etree import ElementTree as ET
from collections import defaultdict

def iter_objects(xml_path):
    for event, elem in ET.iterparse(xml_path, events=("end",)):
        if elem.tag == "OBJECT":
            props = {}
            for prop in elem.findall("PROPERTY"):
                name = prop.attrib.get("NAME")
                val = prop.attrib.get("VALUE")
                if name is not None:
                    props[name] = val
            t = props.get("__type")
            yield t, props
            elem.clear()

def ensure_xml(path):
    if path.lower().endswith(".zip"):
        with zipfile.ZipFile(path, "r") as zf:
            target = None
            for n in zf.namelist():
                if n.endswith("onedb.xml"):
                    target = n
                    break
            if not target:
                raise FileNotFoundError("onedb.xml not found in ZIP")
            outdir = Path(path).with_suffix("")
            outdir.mkdir(parents=True, exist_ok=True)
            zf.extract(target, outdir)
            return str(outdir / target)
    return path

def parse_option_def_key(s):
    # Parse strings like 'DHCP..false.33' -> (space, is_ipv6, code). Fallback: trailing digits as code.
    if not s:
        return (None, None, None)
    parts = s.split(".")
    code = None
    for p in reversed(parts):
        if p.isdigit():
            code = p
            break
    space = parts[0] if parts else None
    is_v6 = None
    for p in parts:
        if p.lower() in ("true","false"):
            is_v6 = (p.lower()=="true")
            break
    return (space, is_v6, code)

def zone_internal_key(zprops):
    z = zprops.get("zone") or ""
    n = zprops.get("name") or ""
    if n and z:
        return (z + "." + n).replace("..", ".")
    return z or n

def extract_dns_view(zone_internal: str) -> str:
    if not zone_internal:
        return ""
    s = zone_internal.lstrip(".")
    return s.split(".", 1)[0] if "." in s else s

def write_csv(path: Path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fieldnames})
    return path

def main():
    ap = argparse.ArgumentParser(description="Generate DNS/DHCP overview from Infoblox onedb.xml")
    ap.add_argument("input", help="Path to onedb.xml or onedb.xml.zip")
    ap.add_argument("-o", "--outdir", default="infoblox_overview_out", help="Output directory")
    ap.add_argument("--filter-view", help="Only include zones (and forwarders) from this DNS view name")
    ap.add_argument("--split-views", action="store_true", help="Emit per-view zone CSVs")
    ap.add_argument("--no-sorted-by-view", action="store_true", help="Skip generating zones_overview_by_view.csv")
    args = ap.parse_args()

    xml_path = ensure_xml(args.input)
    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    zones = []
    zone_props_map = {}
    forwarders_by_zone = defaultdict(list)
    forwarding_server_flags = {}
    ad_servers_by_zone = defaultdict(list)

    networks = []
    ranges = []
    reservations = []
    options_by_parent = defaultdict(list)

    option_defs = {}
    for t, props in iter_objects(xml_path):
        if t == ".com.infoblox.dns.option_definition":
            name = props.get("name","")
            code = props.get("code","")
            space = props.get("option_space","") or "DHCP"
            is_v6 = (props.get("is_ipv6","false").lower() == "true") if "is_ipv6" in props else False
            option_defs[(space, is_v6, code)] = name

    for t, props in iter_objects(xml_path):
        if not t:
            continue
        if t == ".com.infoblox.dns.zone":
            zones.append(props)
        elif t == ".com.infoblox.dns.zone_properties":
            zid = props.get("zone") or props.get("parent")
            if zid:
                zone_props_map[zid] = props
        elif t == ".com.infoblox.dns.zone_forwarder":
            z = props.get("zone")
            if z:
                forwarders_by_zone[z].append({
                    "position": props.get("position"),
                    "address": props.get("address"),
                    "ds_name": props.get("ds_name"),
                })
        elif t == ".com.infoblox.dns.zone_forwarding_server":
            z = props.get("zone")
            if z and z not in forwarding_server_flags:
                forwarding_server_flags[z] = {
                    "forwarders_only": props.get("forwarders_only"),
                    "use_override_forwarders": props.get("use_override_forwarders"),
                }
        elif t == ".com.infoblox.dns.zone_ad_server":
            z = props.get("zone")
            if z:
                ad_servers_by_zone[z].append(props.get("address"))
        elif t == ".com.infoblox.dns.network":
            networks.append(props)
        elif t == ".com.infoblox.dns.dhcp_range":
            ranges.append(props)
        elif t == ".com.infoblox.dns.fixed_address":
            reservations.append(props)
        elif t == ".com.infoblox.dns.option":
            parent = props.get("parent")
            od = props.get("option_definition","")
            space, is_v6, code = parse_option_def_key(od)
            name = option_defs.get((space or "DHCP", bool(is_v6), code or ""), "")
            options_by_parent[parent].append({
                "space": space or "",
                "code": code or "",
                "name": name,
                "value": props.get("value",""),
                "is_ipv4": props.get("is_ipv4",""),
            })

    zone_rows = []
    for z in zones:
        zr = {}
        zr["zone_fqdn"] = z.get("fqdn") or z.get("display_name") or ""
        zr["zone_internal"] = zone_internal_key(z)
        zr["dns_view"] = extract_dns_view(zr["zone_internal"])
        zr["zone_type"] = z.get("zone_type") or ""
        zr["primary_type"] = z.get("primary_type") or ""
        zr["is_external_primary"] = z.get("is_external_primary") or ""
        zr["is_multimaster"] = z.get("is_multimaster") or ""
        zr["disabled"] = z.get("disabled") or ""
        zp = zone_props_map.get(zr["zone_internal"], {})
        zr["allow_ddns_updates"] = zp.get("allow_ddns_updates","")
        zr["ms_ddns_mode"] = zp.get("ms_ddns_mode","")
        zr["ddns_principal_tracking"] = zp.get("ddns_principal_tracking","")
        zr["ddns_restrict_secure"] = zp.get("ddns_restrict_secure","")
        zr["zone_transfer_list_option"] = zp.get("zone_transfer_list_option","")
        zr["check_names_for_ddns_and_zone_transfer"] = zp.get("check_names_for_ddns_and_zone_transfer","")
        fwd_list = forwarders_by_zone.get(zr["zone_internal"], [])
        zr["forwarder_count"] = str(len(fwd_list)) if fwd_list else "0"
        flags = forwarding_server_flags.get(zr["zone_internal"], {})
        zr["forwarders_only"] = flags.get("forwarders_only","")
        zr["use_override_forwarders"] = flags.get("use_override_forwarders","")
        zr["ad_dns_servers"] = ",".join(ad_servers_by_zone.get(zr["zone_internal"], []))
        zone_rows.append(zr)

    if args.filter_view:
        want = args.filter_view
        zone_rows = [r for r in zone_rows if r.get("dns_view")==want]

    zone_fields = [
        "zone_fqdn","zone_type","primary_type","is_external_primary","is_multimaster","disabled",
        "allow_ddns_updates","ms_ddns_mode","ddns_principal_tracking","ddns_restrict_secure",
        "zone_transfer_list_option","check_names_for_ddns_and_zone_transfer",
        "forwarder_count","forwarders_only","use_override_forwarders",
        "ad_dns_servers","zone_internal","dns_view"
    ]
    write_csv(outdir / "zones_overview.csv", zone_fields, zone_rows)

    if not args.no_sorted_by_view:
        zone_rows_sorted = sorted(zone_rows, key=lambda r: (r.get("dns_view",""), r.get("zone_fqdn","")))
        write_csv(outdir / "zones_overview_by_view.csv", zone_fields, zone_rows_sorted)

    if args.split_views:
        by_view = defaultdict(list)
        for r in zone_rows:
            by_view[r.get("dns_view","")].append(r)
        for view, rows in by_view.items():
            safe_view = (view or "no_view").replace("/", "_").replace("\\", "_")
            write_csv(outdir / f"zones_overview_view_{safe_view}.csv", zone_fields, rows)

    fwd_rows = []
    for z in zones:
        zin = zone_internal_key(z)
        dns_view = extract_dns_view(zin)
        if args.filter_view and dns_view != args.filter_view:
            continue
        for fwd in forwarders_by_zone.get(zin, []):
            f = {
                "zone_fqdn": z.get("fqdn") or z.get("display_name") or "",
                "zone_internal": zin,
                "dns_view": dns_view,
                "position": fwd.get("position",""),
                "forwarder_ip": fwd.get("address",""),
                "forwarder_name": fwd.get("ds_name",""),
            }
            fwd_rows.append(f)
    fwd_fields = ["zone_fqdn","dns_view","position","forwarder_ip","forwarder_name","zone_internal"]
    write_csv(outdir / "zone_forwarders.csv", fwd_fields, fwd_rows)

    zff_rows = []
    for z in zones:
        zin = zone_internal_key(z)
        dns_view = extract_dns_view(zin)
        if args.filter_view and dns_view != args.filter_view:
            continue
        flags = forwarding_server_flags.get(zin, {})
        if flags:
            zff_rows.append({
                "zone_fqdn": z.get("fqdn") or z.get("display_name") or "",
                "zone_internal": zin,
                "dns_view": dns_view,
                "forwarders_only": flags.get("forwarders_only",""),
                "use_override_forwarders": flags.get("use_override_forwarders",""),
            })
    if zff_rows:
        write_csv(outdir / "zone_forwarding_flags.csv", ["zone_fqdn","dns_view","zone_internal","forwarders_only","use_override_forwarders"], zff_rows)

    net_fields = [
        "network","cidr","is_ipv4","disabled","authoritative","lease_time","comment",
        "ddns_updates_enabled","ddns_server_use_fqdn","ddns_no_client_fqdn","ddns_use_client_fqdn","ddns_domainname","ddns_ttl",
        "override_custom_options","override_ddns_updates","override_domain_name_servers","override_routers",
        "broadcast_address","domain_name","next_server","boot_server","boot_file","options_json"
    ]
    net_rows = []
    for n in networks:
        parent_id = f".com.infoblox.dns.network${n.get('address','')}/{n.get('cidr','')}/{n.get('network_view','0')}"
        row = {
            "network": f"{n.get('address','')}/{n.get('cidr','')}",
            "cidr": n.get("cidr",""),
            "is_ipv4": n.get("is_ipv4",""),
            "disabled": n.get("disabled",""),
            "authoritative": n.get("authoritative",""),
            "lease_time": n.get("lease_time",""),
            "comment": n.get("comment",""),
            "ddns_updates_enabled": n.get("ddns_updates_enabled",""),
            "ddns_server_use_fqdn": n.get("ddns_server_use_fqdn",""),
            "ddns_no_client_fqdn": n.get("ddns_no_client_fqdn",""),
            "ddns_use_client_fqdn": n.get("ddns_use_client_fqdn",""),
            "ddns_domainname": n.get("ddns_domainname",""),
            "ddns_ttl": n.get("ddns_ttl",""),
            "override_custom_options": n.get("override_custom_options",""),
            "override_ddns_updates": n.get("override_ddns_updates",""),
            "override_domain_name_servers": n.get("override_domain_name_servers",""),
            "override_routers": n.get("override_routers",""),
            "broadcast_address": n.get("broadcast_address",""),
            "domain_name": n.get("domain_name",""),
            "next_server": n.get("next_server",""),
            "boot_server": n.get("boot_server",""),
            "boot_file": n.get("boot_file",""),
            "options_json": json.dumps(options_by_parent.get(parent_id, []), ensure_ascii=False),
        }
        net_rows.append(row)
    write_csv(outdir / "dhcp_networks.csv", net_fields, net_rows)

    range_fields = [
        "network","start_address","end_address","is_ipv4","disabled","member","lease_time","comment",
        "override_custom_options","override_domain_name_servers","override_routers",
        "next_server","boot_server","boot_file","options_json"
    ]
    range_rows = []
    for r in ranges:
        parent_id = f".com.infoblox.dns.dhcp_range${r.get('start_address','')}-{r.get('end_address','')}/{r.get('network_view','0')}"
        row = {
            "network": r.get("network",""),
            "start_address": r.get("start_address",""),
            "end_address": r.get("end_address",""),
            "is_ipv4": r.get("is_ipv4",""),
            "disabled": r.get("disabled",""),
            "member": r.get("member",""),
            "lease_time": r.get("lease_time",""),
            "comment": r.get("comment",""),
            "override_custom_options": r.get("override_custom_options",""),
            "override_domain_name_servers": r.get("override_domain_name_servers",""),
            "override_routers": r.get("override_routers",""),
            "next_server": r.get("next_server",""),
            "boot_server": r.get("boot_server",""),
            "boot_file": r.get("boot_file",""),
            "options_json": json.dumps(options_by_parent.get(parent_id, []), ensure_ascii=False),
        }
        range_rows.append(row)
    write_csv(outdir / "dhcp_ranges.csv", range_fields, range_rows)

    res_fields = ["ip","mac","name","domain_name","network","network_view","lease_time","comment"]
    res_rows = []
    for h in reservations:
        res_rows.append({
            "ip": h.get("ip_address","") or h.get("ipv4addr",""),
            "mac": h.get("mac_address","") or h.get("mac",""),
            "name": h.get("name",""),
            "domain_name": h.get("domain_name",""),
            "network": h.get("network",""),
            "network_view": h.get("network_view",""),
            "lease_time": h.get("lease_time",""),
            "comment": h.get("comment",""),
        })
    write_csv(outdir / "dhcp_reservations.csv", res_fields, res_rows)

    counts = defaultdict(int)
    for r in zone_rows:
        counts[(r.get("dns_view",""), r.get("zone_type",""))] += 1
    summary_rows = [{"dns_view": k[0], "zone_type": k[1], "count": v} for k,v in counts.items()]
    write_csv(outdir / "zones_by_view_summary.csv", ["dns_view","zone_type","count"], summary_rows)

    print(json.dumps({
        "zones": len(zone_rows),
        "forward_zones": sum(1 for r in zone_rows if r.get('zone_type')=='Forward'),
        "dhcp_networks": len(networks),
        "dhcp_ranges": len(ranges),
        "dhcp_reservations": len(reservations),
        "outdir": str(outdir),
    }, indent=2))

if __name__ == "__main__":
    main()
