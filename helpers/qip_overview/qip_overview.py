#!/usr/bin/env python3

# This script generates a compact, operator‑friendly overview of a QIP export (QEF files).
# It parses the export directory and writes CSV overviews for zones, subnets (v4/v6), ranges, and more.
# DHCP pools and reservations are derived directly from obj_prof.qef to match production behavior, with numeric sorting and CIDR‑aware metadata.
# Output filenames are automatically prefixed with the input folder name.  

import argparse
import json
from pathlib import Path
import pandas as pd
import ipaddress

def read_csv_safe(path: Path) -> pd.DataFrame:
    if not path or not path.exists():
        return pd.DataFrame()
    try:
        return pd.read_csv(path, dtype=str, low_memory=False)
    except Exception as e:
        print(f"[WARN] Failed to read {path}: {e}")
        return pd.DataFrame()

def find_ci(root: Path, basename: str) -> Path | None:
    p = root / basename
    if p.exists():
        return p
    for f in root.rglob("*"):
        if f.is_file() and f.name.lower() == basename.lower():
            return f
    return None

def write_csv(df: pd.DataFrame, out_dir: Path, prefix: str, stem: str):
    if df is None or df.empty:
        return None
    out = out_dir / f"{prefix}_{stem}.csv"
    df.to_csv(out, index=False)
    return out

def concat_ip_parts(df: pd.DataFrame, cols):
    parts = df[cols].fillna('')
    return parts.apply(lambda r: ".".join([x for x in r if x and x.lower() != 'nan']), axis=1)

def ipv4_from_octets(df, a='obj_ip_addr1', b='obj_ip_addr2', c='obj_ip_addr3', d='obj_ip_addr4'):
    for col in [a,b,c,d]:
        df[col] = df[col].astype(str)
    return df[[a,b,c,d]].agg(".".join, axis=1)

def ipv4_to_int(ip_str):
    try:
        return int(ipaddress.IPv4Address(ip_str))
    except Exception:
        return None

def contiguous_ranges(int_series):
    runs = []
    start = prev = None
    for val in int_series:
        if val is None:
            continue
        if start is None:
            start = prev = val
        elif val == prev + 1:
            prev = val
        else:
            runs.append((start, prev))
            start = prev = val
    if start is not None:
        runs.append((start, prev))
    return runs

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("qef_dir", help="Directory with QEF files")
    ap.add_argument("--out", default="qip_overview_out", help="Output directory")
    args = ap.parse_args()

    src = Path(args.qef_dir)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    prefix = src.name.rstrip("/")

    # Load core dataframes
    dom           = read_csv_safe(find_ci(src, "domain.qef"))
    rev           = read_csv_safe(find_ci(src, "reverse_zones.qef"))
    dns_view      = read_csv_safe(find_ci(src, "dns_view.qef"))
    dns_view_zone = read_csv_safe(find_ci(src, "dns_view_zone.qef"))
    zsrvr         = read_csv_safe(find_ci(src, "zone_servers.qef"))
    dns_vzs       = read_csv_safe(find_ci(src, "dns_view_zone_server.qef"))
    networks      = read_csv_safe(find_ci(src, "networks.qef"))
    sub4          = read_csv_safe(find_ci(src, "subnet.qef"))
    sub6          = read_csv_safe(find_ci(src, "v6subnet.qef"))
    ranges        = read_csv_safe(find_ci(src, "managed_range.qef"))
    dhcp_ext      = read_csv_safe(find_ci(src, "dhcp_ext.qef"))
    obj_ranges    = read_csv_safe(find_ci(src, "object_ranges.qef"))
    obj_prof      = read_csv_safe(find_ci(src, "obj_prof.qef"))
    sdom          = read_csv_safe(find_ci(src, "subnet_domns.qef"))
    dom_uda       = read_csv_safe(find_ci(src, "domain_uda.qef"))
    sub_uda       = read_csv_safe(find_ci(src, "subnet_uda.qef"))
    srvrs         = read_csv_safe(find_ci(src, "srvrs.qef"))

    # Zones
    fwd = pd.DataFrame()
    if not dom.empty:
        fwd = dom.rename(columns={"domn_id":"zone_id","domn_name":"zone_name","status_flag":"status","reversed_name":"reversed_name","org_id":"org_id"})
        fwd["zone_kind"] = "forward"
        keep = [c for c in ["zone_id","zone_kind","zone_name","status","reversed_name","org_id"] if c in fwd.columns]
        fwd = fwd[keep]

    rvs = pd.DataFrame()
    if not rev.empty:
        rvs = rev.rename(columns={"zone_id":"zone_id","name":"zone_name","status_flag":"status","reversed_name":"reversed_name"})
        rvs["zone_kind"] = "reverse"
        keep = ["zone_id","zone_kind","zone_name","status","reversed_name"]
        for c in ["zone_addr1","zone_addr2","zone_addr3","zone_addr4","mask_length","prefix_length","start_addr","end_addr"]:
            if c in rvs.columns: keep.append(c)
        rvs = rvs[keep]

    zones = pd.concat([fwd, rvs], ignore_index=True) if (not fwd.empty or not rvs.empty) else pd.DataFrame()

    # Views
    views = pd.DataFrame()
    if not dns_view.empty:
        keep = [c for c in ["dns_view_id","name","org_id","site_id","match_clients","match_destinations","match_recursive_only"] if c in dns_view.columns]
        views = dns_view[keep] if keep else dns_view

    dvz = pd.DataFrame()
    if not dns_view_zone.empty:
        dvz_cols = [c for c in ["dns_view_zone_id","dns_view_id","zone_id","zone_type","name","reversed_name","refresh_time","retry_time","expire_time","min_time","neg_cache_ttl","use_global_options"] if c in dns_view_zone.columns]
        dvz = dns_view_zone[dvz_cols]
    dvzs = dvz.merge(zones[["zone_id","zone_name","zone_kind"]], on="zone_id", how="left") if (not dvz.empty and not zones.empty) else pd.DataFrame()

    # Zone ↔ Server mapping (counts + names)
    zones_srv = pd.DataFrame()
    if not zones.empty and not zsrvr.empty:
        zkeep = [c for c in ["zone_id","dns_svr_id","status_flag","root_zone","send_securednsupdates","zone_select_flag"] if c in zsrvr.columns]
        z_small = zsrvr[zkeep].copy()

        counts = z_small.groupby("zone_id")["dns_svr_id"].nunique().reset_index(name="server_count")
        zones_srv = zones.merge(counts, on="zone_id", how="left")
        zones_srv["server_count"] = zones_srv["server_count"].fillna(0).astype(int)

        if not srvrs.empty and "server_id" in srvrs.columns:
            s = srvrs.copy()
            if "type_code" in s.columns:
                try:
                    s = s[s["type_code"].astype(str) == "103"]
                except Exception:
                    pass
            z_named = z_small.copy()
            z_named["dns_svr_id"] = z_named["dns_svr_id"].astype(str)
            s["server_id"] = s["server_id"].astype(str)
            z_named = z_named.merge(s[["server_id","server_name"]], left_on="dns_svr_id", right_on="server_id", how="left")
            agg = (z_named.groupby("zone_id")["server_name"]
                   .apply(lambda v: ";".join(sorted([x for x in set(v.dropna()) if x != ""])))
                   .reset_index(name="server_names"))
            zones_srv = zones_srv.merge(agg, on="zone_id", how="left")

    # Subnets (compute mask_length if needed)
    if not sub4.empty:
        if {"subnet_addr1","subnet_addr2","subnet_addr3","subnet_addr4"}.issubset(sub4.columns):
            sub4["subnet_ip"] = concat_ip_parts(sub4, ["subnet_addr1","subnet_addr2","subnet_addr3","subnet_addr4"])
        keep = [c for c in ["subnet_id","subnet_name","subnet_ip","mask_length","subnet_mask1","subnet_mask2","subnet_mask3","subnet_mask4","domn_id","org_id","status_flag"] if c in sub4.columns]
        sub4 = sub4[keep]
        if "mask_length" not in sub4.columns:
            n = len(sub4)
            m1 = sub4["subnet_mask1"] if "subnet_mask1" in sub4.columns else pd.Series(["255"]*n)
            m2 = sub4["subnet_mask2"] if "subnet_mask2" in sub4.columns else pd.Series(["0"]*n)
            m3 = sub4["subnet_mask3"] if "subnet_mask3" in sub4.columns else pd.Series(["0"]*n)
            m4 = sub4["subnet_mask4"] if "subnet_mask4" in sub4.columns else pd.Series(["0"]*n)
            def _oct_to_bits(v):
                try:
                    return bin(int(str(v))).count("1")
                except Exception:
                    return 0
            sub4["mask_length"] = [ _oct_to_bits(a)+_oct_to_bits(b)+_oct_to_bits(c)+_oct_to_bits(d) for a,b,c,d in zip(m1, m2, m3, m4) ]

    # DHCP ext lease stats
    lease_stats = pd.DataFrame()
    if not dhcp_ext.empty:
        if "client_vendor_class" in dhcp_ext.columns:
            vc = (dhcp_ext["client_vendor_class"].fillna("").replace("", "UNKNOWN")
                  .value_counts().head(10).reset_index())
            vc.columns = ["client_vendor_class","count"]
            lease_stats = vc
        else:
            lease_stats = pd.DataFrame({"total_rows":[len(dhcp_ext)]})

    # DHCP ranges (prefer obj_prof contiguous ranges with alloc_type_cd==3)
    dhcp_ranges = pd.DataFrame()
    if not obj_prof.empty and {"subnet_id","alloc_type_cd","obj_ip_addr1","obj_ip_addr2","obj_ip_addr3","obj_ip_addr4"}.issubset(set(obj_prof.columns)):
        op = obj_prof[["subnet_id","alloc_type_cd","obj_ip_addr1","obj_ip_addr2","obj_ip_addr3","obj_ip_addr4"]].copy()
        try:
            op_dyn = op[op["alloc_type_cd"].astype(str) == "3"].copy()
        except Exception:
            op_dyn = op.copy()
        if not op_dyn.empty:
            op_dyn["ip"] = ipv4_from_octets(op_dyn)
            op_dyn["ip_int"] = op_dyn["ip"].apply(ipv4_to_int)
            rows = []
            for sid, grp in op_dyn.groupby("subnet_id", dropna=False):
                ints = sorted([x for x in grp["ip_int"].tolist() if x is not None])
                for s, e in contiguous_ranges(ints):
                    rows.append({"subnet_id": sid, "first_ip": str(ipaddress.IPv4Address(s)), "last_ip": str(ipaddress.IPv4Address(e))})
            dhcp_ranges = pd.DataFrame(rows)
    elif not obj_ranges.empty and {"first_address","last_address"}.issubset(set(obj_ranges.columns)):
        dr = obj_ranges.copy()
        def _to_ip(x):
            try:
                if x is None or x == "" or str(x).lower() == "nan": return None
                n = int(float(x))
                return str(ipaddress.IPv4Address(n))
            except Exception:
                return None
        dr["first_ip"] = dr["first_address"].apply(_to_ip)
        dr["last_ip"]  = dr["last_address"].apply(_to_ip)
        keep = [c for c in ["obj_range_id","subnet_id","first_ip","last_ip"] if c in dr.columns or c in ["first_ip","last_ip"]]
        dhcp_ranges = dr[keep].drop_duplicates()
    elif not ranges.empty:
        keep = [c for c in ["managed_range_id","version","start_offset","end_offset","number_of_objects","address_type","lease_time","object_class_id","user_class_id","vendor_class_id","domn_id","server_id","option_temp_id","policy_temp_id","iface_name","address_template_id"] if c in ranges.columns]
        dhcp_ranges = ranges[keep].copy()

    # Attach subnet details to ranges to build CIDR
    if not dhcp_ranges.empty and not sub4.empty and "subnet_id" in dhcp_ranges.columns:
        _sn = sub4[[c for c in ["subnet_id","subnet_ip","mask_length"] if c in sub4.columns]].drop_duplicates()
        dhcp_ranges = dhcp_ranges.merge(_sn, on="subnet_id", how="left")
        if {"subnet_ip","mask_length"}.issubset(dhcp_ranges.columns):
            dhcp_ranges["network_cidr"] = dhcp_ranges["subnet_ip"].astype(str) + "/" + dhcp_ranges["mask_length"].astype(str)
            dhcp_ranges["subnet_ip"] = dhcp_ranges["network_cidr"]

    # DHCP reservations: prefer obj_prof alloc_type_cd==1
    dhcp_res = pd.DataFrame()
    if not obj_prof.empty and {"obj_id","alloc_type_cd","obj_ip_addr1","obj_ip_addr2","obj_ip_addr3","obj_ip_addr4","subnet_id"}.issubset(set(obj_prof.columns)):
        op = obj_prof[["obj_id","alloc_type_cd","obj_ip_addr1","obj_ip_addr2","obj_ip_addr3","obj_ip_addr4","subnet_id"]].copy()
        try:
            op_stat = op[op["alloc_type_cd"].astype(str) == "1"].copy()
        except Exception:
            op_stat = op.copy()
        if not op_stat.empty:
            op_stat["ip_address"] = ipv4_from_octets(op_stat)
            dhcp_res = op_stat[["obj_id","ip_address","subnet_id"]].drop_duplicates()
    else:
        if not dhcp_ext.empty:
            de = dhcp_ext.copy()
            if "manual_flag" in de.columns:
                try:
                    de["manual_flag_int"] = de["manual_flag"].fillna("0").astype(int)
                except Exception:
                    de["manual_flag_int"] = 0
            else:
                de["manual_flag_int"] = 0
            has_no_lease = (~de.get("lease_granted", pd.Series([None]*len(de))).notna()) & (~de.get("lease_expires", pd.Series([None]*len(de))).notna())
            has_identity = de.get("mac_addr", pd.Series([""]*len(de))).fillna("") != ""
            de = de[(de["manual_flag_int"] == 1) | (has_no_lease & has_identity)].copy()
            oi = read_csv_safe(find_ci(src, "object_interface.qef"))
            if not oi.empty and {"obj_id","full_addr_str"}.issubset(set(oi.columns)):
                de = de.merge(oi[["obj_id","full_addr_str"]], on="obj_id", how="left").rename(columns={"full_addr_str":"ip_address"})
            dhcp_res = de[[c for c in ["obj_id","ip_address","subnet_id","mac_addr","client_id","client_vendor_class","lease_granted","lease_expires","manual_flag"] if c in de.columns]].drop_duplicates()

    # Attach subnet details and DHCP ext enrichment to reservations
    if not dhcp_res.empty:
        if not sub4.empty and "subnet_id" in dhcp_res.columns:
            _sn = sub4[[c for c in ["subnet_id","subnet_ip","mask_length"] if c in sub4.columns]].drop_duplicates()
            dhcp_res = dhcp_res.merge(_sn, on="subnet_id", how="left")
            if {"subnet_ip","mask_length"}.issubset(dhcp_res.columns):
                dhcp_res["network_cidr"] = dhcp_res["subnet_ip"].astype(str) + "/" + dhcp_res["mask_length"].astype(str)
                dhcp_res["subnet_ip"] = dhcp_res["network_cidr"]
        if not dhcp_ext.empty and "obj_id" in dhcp_ext.columns:
            attach_cols = [c for c in ["obj_id","mac_addr","client_id","client_vendor_class","lease_granted","lease_expires","manual_flag"] if c in dhcp_ext.columns]
            if attach_cols:
                dhcp_res = dhcp_res.merge(dhcp_ext[attach_cols], on="obj_id", how="left")

    # Sorting
    if not dhcp_ranges.empty:
        dhcp_ranges["_subnet_id_int"] = pd.to_numeric(dhcp_ranges["subnet_id"], errors="coerce")
        def _ip_to_int(x):
            try:
                return int(ipaddress.IPv4Address(str(x)))
            except Exception:
                return None
        if "first_ip" in dhcp_ranges.columns:
            dhcp_ranges["_first_ip_int"] = dhcp_ranges["first_ip"].apply(_ip_to_int)
        else:
            dhcp_ranges["_first_ip_int"] = None
        dhcp_ranges = dhcp_ranges.sort_values(by=["_subnet_id_int","_first_ip_int","subnet_id","first_ip"], kind="mergesort").drop(columns=["_subnet_id_int","_first_ip_int"], errors="ignore")

    if not dhcp_res.empty and "ip_address" in dhcp_res.columns:
        dhcp_res["_subnet_id_int"] = pd.to_numeric(dhcp_res["subnet_id"], errors="coerce") if "subnet_id" in dhcp_res.columns else 0
        def _ip_to_int2(x):
            try:
                return int(ipaddress.IPv4Address(str(x)))
            except Exception:
                return None
        dhcp_res["_ip_int"] = dhcp_res["ip_address"].apply(_ip_to_int2)
        dhcp_res = dhcp_res.sort_values(by=["_subnet_id_int","_ip_int","subnet_id","ip_address"], kind="mergesort").drop(columns=["_subnet_id_int","_ip_int"], errors="ignore")

    # Make dhcp_ranges concise: keep only essential columns (subnet_ip already includes CIDR)
    if not dhcp_ranges.empty:
        keep_cols = [c for c in ["subnet_id","first_ip","last_ip","subnet_ip","mask_length"] if c in dhcp_ranges.columns]
        dhcp_ranges = dhcp_ranges[keep_cols]

    # ---- Extended summary reflecting the updated outputs ----
    def _ip_to_int_for_sum(x):
        try:
            return int(ipaddress.IPv4Address(str(x)))
        except Exception:
            return None

    dhcp_range_spans_count = int(len(dhcp_ranges)) if (isinstance(dhcp_ranges, pd.DataFrame) and not dhcp_ranges.empty) else 0
    dhcp_range_subnets_count = int(dhcp_ranges["subnet_id"].nunique()) if dhcp_range_spans_count and "subnet_id" in dhcp_ranges.columns else 0

    total_range_addresses = 0
    if dhcp_range_spans_count and {"first_ip","last_ip"}.issubset(dhcp_ranges.columns):
        _tmp = dhcp_ranges[["first_ip","last_ip"]].copy()
        _tmp["first_int"] = _tmp["first_ip"].apply(_ip_to_int_for_sum)
        _tmp["last_int"]  = _tmp["last_ip"].apply(_ip_to_int_for_sum)
        _tmp = _tmp.dropna()
        if not _tmp.empty:
            total_range_addresses = int((_tmp["last_int"] - _tmp["first_int"] + 1).clip(lower=0).sum())

    dhcp_reservations_count = int(len(dhcp_res)) if (isinstance(dhcp_res, pd.DataFrame) and not dhcp_res.empty) else 0
    dhcp_res_subnets_count = int(dhcp_res["subnet_id"].nunique()) if dhcp_reservations_count and "subnet_id" in dhcp_res.columns else 0

    obj_prof_rows = int(len(obj_prof)) if not obj_prof.empty else 0
    object_ranges_rows = int(len(obj_ranges)) if not obj_ranges.empty else 0

    summary = {
        "forward_zone_count": int(len(dom)) if not dom.empty else 0,
        "reverse_zone_count": int(len(rev)) if not rev.empty else 0,
        "views_count": int(len(dns_view)) if not dns_view.empty else 0,
        "dvz_mappings": int(len(dns_view_zone)) if not dns_view_zone.empty else 0,
        "zone_server_links": int(len(dns_vzs)) if not dns_vzs.empty else (int(len(zsrvr)) if not zsrvr.empty else 0),
        "networks_count": int(len(networks)) if not networks.empty else 0,
        "subnets_v4_count": int(len(sub4)) if not sub4.empty else 0,
        "subnets_v6_count": int(len(sub6)) if not sub6.empty else 0,
        "managed_ranges_count": int(len(ranges)) if not ranges.empty else 0,
        "dhcp_ext_rows": int(len(dhcp_ext)) if not dhcp_ext.empty else 0,
        "obj_prof_rows": obj_prof_rows,
        "object_ranges_rows": object_ranges_rows,
        "dhcp_range_spans_count": dhcp_range_spans_count,
        "dhcp_range_subnets_count": dhcp_range_subnets_count,
        "total_range_addresses": total_range_addresses,
        "dhcp_reservations_count": dhcp_reservations_count,
        "dhcp_res_subnets_count": dhcp_res_subnets_count
    }
    (out / f"{prefix}_summary.json").write_text(json.dumps(summary, indent=2))

    # Write outputs
    written = {}
    written["zones_overview"]        = str(write_csv(zones, out, prefix, "zones_overview"))
    written["zone_servers_overview"] = str(write_csv(zones_srv, out, prefix, "zone_servers_overview"))
    written["views_overview"]        = str(write_csv(dvzs, out, prefix, "views_overview"))
    written["networks_overview"]     = str(write_csv(networks, out, prefix, "networks_overview"))
    written["subnets_overview"]      = str(write_csv(sub4, out, prefix, "subnets_overview"))
    written["subnets_v6_overview"]   = str(write_csv(sub6, out, prefix, "subnets_v6_overview"))
    written["dhcp_overview"]         = str(write_csv(ranges, out, prefix, "dhcp_overview"))
    written["dhcp_lease_stats"]      = str(write_csv(lease_stats, out, prefix, "dhcp_lease_stats"))
    written["dhcp_ranges"]           = str(write_csv(dhcp_ranges, out, prefix, "dhcp_ranges"))
    written["dhcp_reservations"]     = str(write_csv(dhcp_res, out, prefix, "dhcp_reservations"))

    print(json.dumps(summary, indent=2))
    print(json.dumps({"written": written}, indent=2))

if __name__ == "__main__":
    main()
