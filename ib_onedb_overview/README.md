# ib_onedb_overview.py

## Description
Parses an **Infoblox OneDB** XML export (`onedb.xml`) and generates CSV summaries for **DNS zones** (zone type, primaries, forwarders, AD integration, Dynamic DNS settings) and **DHCP** configuration (networks, ranges, reservations, custom DHCP options). Zones are grouped by DNS view and can be filtered or split per view.

---

## Usage
Basic:
```bash
python ib_onedb_overview.py onedb.xml
```

ZIP input:
```bash
python ib_onedb_overview.py /path/to/onedb.xml
```

Custom output directory:
```bash
python ib_onedb_overview.py onedb.xml -o ./infoblox_overview_out
```

Filter to a single DNS view:
```bash
python ib_onedb_overview.py onedb.xml --filter-view "Internal"
```

Generate per‑view CSVs and keep the default by‑view sort:
```bash
python ib_onedb_overview.py onedb.xml --split-views
```

Skip the consolidated by‑view CSV:
```bash
python ib_onedb_overview.py onedb.xml --no-sorted-by-view
```

### CLI
```text
positional arguments:
  input                 Path to onedb.xml

optional arguments:
  -o, --outdir          Output directory (default: infoblox_overview_out)
  --filter-view NAME    Only include zones/forwarders from this DNS view
  --split-views         Emit per-view zone CSVs
  --no-sorted-by-view   Skip zones_overview_by_view.csv
```

**Stdout:** At the end, the script prints a JSON summary with counts, e.g.:
```json
{
  "zones": 123,
  "forward_zones": 45,
  "dhcp_networks": 67,
  "dhcp_ranges": 89,
  "dhcp_reservations": 10,
  "outdir": "infoblox_overview_out"
}
```

---

## Requirements
- **Python:** 3.9+
- **External modules:** None (standard library only)
  - Uses: `argparse`, `os`, `zipfile`, `sys`, `csv`, `json`, `re`, `pathlib`, `xml.etree.ElementTree`, `collections`
- **Vendor-specific dependency:** An **Infoblox OneDB** XML export file (`onedb.xml` or ZIP containing it)

---

## Input / Output
### Input
- `input` (positional): Path to `onedb.xml` or a ZIP that contains `onedb.xml`.
  - ZIPs are auto‑extracted next to the archive into a folder with the same basename.

### Output (CSV files in `--outdir`, default `infoblox_overview_out`)
- **DNS**
  - `zones_overview.csv`  
    - Columns: `zone_fqdn, zone_type, primary_type, is_external_primary, is_multimaster, disabled, allow_ddns_updates, ms_ddns_mode, ddns_principal_tracking, ddns_restrict_secure, zone_transfer_list_option, check_names_for_ddns_and_zone_transfer, forwarder_count, forwarders_only, use_override_forwarders, ad_dns_servers, zone_internal, dns_view`
  - `zones_overview_by_view.csv` (unless `--no-sorted-by-view`)  
    - Same columns as above. Sorted by `(dns_view, zone_fqdn)`.
  - `zones_overview_view_<VIEW>.csv` (only with `--split-views`)
  - `zone_forwarders.csv`  
    - Columns: `zone_fqdn, dns_view, position, forwarder_ip, forwarder_name, zone_internal`
  - `zone_forwarding_flags.csv` (present only if forwarding flags exist)  
    - Columns: `zone_fqdn, dns_view, zone_internal, forwarders_only, use_override_forwarders`

- **DHCP**
  - `dhcp_networks.csv`  
    - Key columns: `network, cidr, is_ipv4, disabled, authoritative, lease_time, comment, ddns_* flags, override_* flags, broadcast_address, domain_name, next_server, boot_server, boot_file, options_json`
  - `dhcp_ranges.csv`  
    - Key columns: `network, start_address, end_address, is_ipv4, disabled, member, lease_time, comment, override_* flags, next_server, boot_server, boot_file, options_json`
  - `dhcp_reservations.csv`  
    - Columns: `ip, mac, name, domain_name, network, network_view, lease_time, comment`

- **Summary**
  - `zones_by_view_summary.csv`  
    - Columns: `dns_view, zone_type, count`
  - **Stdout JSON** with overall counts (see example above)

---

## Notes
- **Scale & performance:** Uses `xml.etree.ElementTree.iterparse` to stream large OneDB files with a low memory footprint.
- **Views:** `zone_internal` is used to derive `dns_view`; you can filter (`--filter-view`) or split outputs (`--split-views`) by view.
- **Forwarders:** Both the per‑zone forwarder list and forwarding‑server flags are exported when present.
- **DHCP options:** Option definitions are matched best‑effort via `(option_space, is_ipv6, code)`; raw values are preserved. Full option sets per parent are serialized to `options_json` as JSON.
- **Input ZIPs:** The script extracts the first `onedb.xml` it finds in the archive.
- **Limitations:**
  - Only a subset of OneDB object types is parsed (zones, zone_properties, forwarders, AD servers, networks, ranges, fixed addresses, options, option_definitions).
  - IPv6 fields are included when present in OneDB; some environments may not populate them consistently.
  - Assumes standard Infoblox object naming for option definitions.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
