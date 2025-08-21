# Little DDI Helpers

A collection of helper scripts for **DNS, DHCP, and IPAM (DDI) projects**.  
These scripts support common consulting and engineering tasks such as:

- Data **migrations** between DDI platforms  
- **Analyzing** DNS, DHCP, and IPAM data  
- **Preparing datasets** for import/export  
- Automating repetitive tasks with APIs or CLI tools  

The repository contains scripts in **Python**, **Shell**, and **PowerShell**.

---

## Directory Listing

```text
|-- bdds_export
|   `-- bdds_export.sh
|-- bdds_health
|   `-- bdds_health.sh
|-- check_dhcp_failover
|   `-- check_dhcp_failover.sh
|-- check_ports
|   `-- check_ports.sh
|-- check_xmls
|   `-- check_xmls.sh
|-- check_zone
|   `-- check_zone.sh
|-- collect_health_check
|   `-- collect_health_check.sh
|-- compare_pattern
|   `-- compare_pattern.sh
|-- compare_zone_variants
|   `-- compare_zone_variants.sh
|-- count_active_leases
|   `-- count_active_leases.sh
|-- ddns_utils
|   |-- ddns_clean-up.sh
|   `-- ddns_update.sh
|-- dependent_records
|   `-- dependent_records.sh
|-- dig_bulk
|   `-- dig_bulk.sh
|-- dig_dump
|   `-- dig_dump.sh
|-- dns_cutover
|   |-- dns_cutover.ps1
|   `-- dns_cutover_restore.ps1
|-- dns_diff_tool
|   `-- dns_diff_tool.sh
|-- dns_health_check
|   `-- dns_health_check.sh
|-- dns_review
|   `-- dns_review.sh
|-- dns_zip2csv
|   `-- dns_zip2csv.sh
|-- dublicated_entries
|   `-- dublicated_entries.sh
|-- export_dhcpd
|   `-- export_dhcpd.sh
|-- export_ms-dns-dhcp
|   `-- export_ms-dns-dhcp.ps1
|-- extract_ms_zip
|   `-- extract_ms_zip.sh
|-- find_zone_duplicates
|   `-- find_zone_duplicates.py
|-- flush_jnl
|   `-- flush_jnl.sh
|-- gen_named
|   `-- gen_named.sh
|-- jumper
|   `-- jumper.sh
|-- merge_csvs
|   `-- merge_csvs.sh
|-- named2csv
|   `-- named2csv.py
|-- nslookup_bulk
|   `-- nslookup_bulk.bat
|-- ptr_clean-up
|   `-- ptr_clean-up.sh
|-- qip_named_normalizer
|   `-- qip_named_normalizer.sh
|-- reverse_from_network
|   `-- reverse_from_network.sh
|-- run_all_servers
|   `-- run_all_servers.sh
|-- server_prefix_groups
|   `-- server_prefix_groups.py
|-- sort_list_of_domains
|   `-- sort_list_of_domains.sh
|-- umlauts
|   `-- umlauts.sh
|-- zone_from_zips
|   `-- zone_from_zips.sh
`-- zone_version_diff
    `-- zone_version_diff.py
```

---