# qip_overview_v6.py

## Description
Generates a compact, operator‑friendly overview of a QIP export (QEF files). It parses the export directory and writes CSV overviews for zones, subnets (v4/v6), ranges, and more.
DHCP pools and reservations are derived directly from `obj_prof.qef` to match production behavior, with numeric sorting and CIDR‑aware metadata.

---

## Usage
Python:
```bash
python qip_overview_v6.py /path/to/qef_dir --out ./qip_overview_out
```

Output filenames are automatically prefixed with the input folder name.  
Example: `/exports/qip_20250901` ⇒ `qip_20250901_views_overview.csv`

---

## Requirements
* Python 3.9+
* pip install pandas

Notes:
* Uses Python stdlib `ipaddress` for IPv4 math
* No internet access or vendor SDKs required

---

## Input / Output

### Input
Point the script at a directory containing QEF files. It will use what is present and skip missing files.

Core QEFs it understands (any subset is fine):
* DNS
  * `domain.qef` (forward zones)
  * `reverse_zones.qef` (reverse zones)
  * `dns_view.qef`, `dns_view_zone.qef`
  * `zone_servers.qef`, `dns_view_zone_server.qef`, `srvrs.qef` (server names)
* IPAM
  * `networks.qef`, `subnet.qef`, `v6subnet.qef`
* DHCP
  * **`obj_prof.qef`** (authoritative source for dynamic pools and static reservations)
  * `object_ranges.qef`, `managed_range.qef` (fallbacks if needed)
  * `dhcp_ext.qef`, `object_interface.qef` (enrichment and fallbacks)

### Output
Written to `--out` and prefixed with the input folder name.

* `*_zones_overview.csv`  
  Forward + reverse zone list.
* `*_zone_servers_overview.csv`  
  Zone to server mapping (includes server_count and server_names when available).
* `*_views_overview.csv`  
  DNS view to zone mappings if present.
* `*_networks_overview.csv`  
  Raw networks metadata if present.
* `*_subnets_overview.csv`  
  IPv4 subnets. If `mask_length` is absent, it is computed from mask octets.
* `*_subnets_v6_overview.csv`  
  IPv6 subnets (overview only).
* `*_dhcp_overview.csv`  
  Raw managed range metadata if present.
* `*_dhcp_lease_stats.csv`  
  Top `client_vendor_class` counts (or total rows as a fallback).
* `*_dhcp_ranges.csv`  
  DHCP pools derived from contiguous `obj_prof.qef` runs with `alloc_type_cd=3`.  
  Columns: `subnet_id, first_ip, last_ip, subnet_ip, mask_length`  
  `subnet_ip` contains the CIDR, sorted by `subnet_id` (numeric), then `first_ip` (numeric).
* `*_dhcp_reservations.csv`  
  Static reservations from `obj_prof.qef` with `alloc_type_cd=1`, enriched with `dhcp_ext.qef` when available.  
  Columns include `obj_id, ip_address, subnet_id, subnet_ip` and optional identity/lease fields.
* `*_summary.json`  
  Roll‑up metrics reflecting what was parsed:
  ```json
  {
    "forward_zone_count": <int>,
    "reverse_zone_count": <int>,
    "views_count": <int>,
    "dvz_mappings": <int>,
    "zone_server_links": <int>,
    "networks_count": <int>,
    "subnets_v4_count": <int>,
    "subnets_v6_count": <int>,
    "managed_ranges_count": <int>,
    "dhcp_ext_rows": <int>,
    "obj_prof_rows": <int>,
    "object_ranges_rows": <int>,
    "dhcp_range_spans_count": <int>,
    "dhcp_range_subnets_count": <int>,
    "total_range_addresses": <int>,
    "dhcp_reservations_count": <int>,
    "dhcp_res_subnets_count": <int>
  }
  ```

---

## Notes
* DHCP pools: built from contiguous addresses in `obj_prof.qef` filtered by `alloc_type_cd=3` (dynamic).  
  Reservations: `alloc_type_cd=1` (static).
* Fallback logic: if `obj_prof.qef` is missing, ranges are taken from `object_ranges.qef` or `managed_range.qef` where possible.
* `mask_length` handling: if absent in `subnet.qef`, computed from `subnet_mask1..4` octets.
* Sorting is numeric for both `subnet_id` and IPv4 addresses to avoid lexicographic anomalies.
* IPv6: included in `*_subnets_v6_overview.csv` but DHCP pool/reservation inference is IPv4‑only in this version.
* The script is read‑only and tolerates partial exports (missing files are skipped).

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
