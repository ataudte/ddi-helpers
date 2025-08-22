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
<details>
  <summary>bdds_export</summary>

* [bdds_export.sh](bdds_export/bdds_export.sh)

**Description**

This script collects DNS and DHCP configuration data from a **BlueCat DNS/DHCP Server (BDDS)** and archives it into a compressed `.tar.gz` file.  
It is intended for backup, migration, or troubleshooting scenarios.

</details>

<details>
  <summary>bdds_health</summary>

* [bdds_health.sh](bdds_health/bdds_health.sh)

**Description**

Health check script for **BlueCat DNS/DHCP Server (BDDS)**.  
It validates prerequisites, collects system and service status (CPU, memory, filesystem, processes), inspects **DNS (named)** and **DHCP (dhcpd)** services, summarizes DHCP lease states, and records BlueCat software version and applied patches.  
All results are written to a timestamped logfile on the BDDS itself.

</details>

<details>
  <summary>check_dhcp_failover</summary>

* [check_dhcp_failover.sh](check_dhcp_failover/check_dhcp_failover.sh)

**Description**

This script checks the **DHCP failover state** on a BlueCat DNS/DHCP Server (BDDS).  
It extracts credentials and association details from the DHCP configuration, connects with `omshell`, and reports both local and partner failover states.

</details>

<details>
  <summary>check_ports</summary>

* [check_ports.sh](check_ports/check_ports.sh)

**Description**

This script checks connectivity for a set of predefined ports across multiple servers provided in an input list.  
It validates TCP/UDP services commonly used in DNS, DHCP, NTP, SNMP, and related applications.  
Results are logged to both the console (with color-coded output) and a timestamped logfile.

</details>

<details>
  <summary>check_xmls</summary>

* [check_xmls.sh](check_xmls/check_xmls.sh)

**Description**

This script scans a given directory for `.zip` files and verifies whether each contains expected DHCP and DNS XML configuration files:

</details>

<details>
  <summary>check_zone</summary>

* [check_zone.sh](check_zone/check_zone.sh)

**Description**

This script performs a **sanity check** on a DNS zone file.  
It can inject a missing `$ORIGIN` directive if needed, runs BIND’s `named-checkzone`, and saves results into a report file.

</details>

<details>
  <summary>collect_health_check</summary>

* [collect_health_check.sh](collect_health_check/collect_health_check.sh)

**Description**

This script automates the collection of health check data from a **BlueCat deployment**, including both:  
- **BlueCat DNS/DHCP Servers (BDDS)**  
- **BlueCat Address Manager (BAM)**  

</details>

<details>
  <summary>compare_pattern</summary>

* [compare_pattern.sh](compare_pattern/compare_pattern.sh)

**Description**

This script compares two files by extracting all lines that contain a given search pattern.  
It normalizes the matches and produces multiple output files, including raw matches, unique matches, common lines, and diffs.

</details>

<details>
  <summary>compare_zone_variants</summary>

* [compare_zone_variants.sh](compare_zone_variants/compare_zone_variants.sh)

**Description**

Compare **DNS zone file variants** that share the **same filename** but live in **different folders** under a root path.  
The script gathers all matching files (by filename pattern), de‑duplicates identical content, cleans MS‑DNS artifacts, **canonicalizes** them with `named-checkzone`, normalizes records (ignore SOA, ignore TTL, lowercase), and then compares **variants of the same basename**.  
Differences are logged; non‑identical canonical variants are preserved for review.

</details>

<details>
  <summary>count_active_leases</summary>

* [count_active_leases.sh](count_active_leases/count_active_leases.sh)

**Description**

This script parses the ISC DHCP **leases file** and counts:
- **Active leases (unique IPs)**  
- **Active clients (unique MAC addresses)**  

</details>

<details>
  <summary>ddns_utils</summary>

* [ddns_clean-up.sh](ddns_utils/ddns_clean-up.sh)
* [ddns_update.sh](ddns_utils/ddns_update.sh)

**Description**

Two shell scripts to **create/update** and **remove** DNS records by feeding `nsupdate` with commands derived from a simple CSV-like input file.

</details>

<details>
  <summary>dependent_records</summary>

* [dependent_records.sh](dependent_records/dependent_records.sh)

**Description**

This script identifies **dependent DNS records** across multiple zones.  
It performs zone transfers (AXFR) from the primary nameserver of each zone, then compares the transferred data with a given list of records to find dependencies.  
Results are written into separate dependency reports for each zone.

</details>

<details>
  <summary>dig_bulk</summary>

* [dig_bulk.sh](dig_bulk/dig_bulk.sh)

**Description**

This script performs bulk DNS queries against a list of servers for a list of zones.  
It checks for the presence of **SOA, NS, and A records** for each zone on each server, logs the results, and reports whether queries succeeded or failed.

</details>

<details>
  <summary>dig_dump</summary>

* [dig_dump.sh](dig_dump/dig_dump.sh)

**Description**

This script runs a `dig` DNS query against a specified DNS server while simultaneously capturing the associated DNS traffic with `tcpdump`.  
The result is a `.pcap` file for later analysis (e.g. in Wireshark) and a tcpdump log file.

</details>

<details>
  <summary>dns_cutover</summary>

* [dns_cutover.ps1](dns_cutover/dns_cutover.ps1)
* [dns_cutover_restore.ps1](dns_cutover/dns_cutover_restore.ps1)

**Description**

PowerShell script to automate a **DNS cutover** on Microsoft Windows DNS Server.  
It reads a CSV with zone configuration and global settings, creates a full backup of the current DNS state, applies changes (secondary zones, forwarders, removals), and logs all actions for audit/handover.  

</details>

<details>
  <summary>dns_diff_tool</summary>

* [dns_diff_tool.sh](dns_diff_tool/dns_diff_tool.sh)

**Description**

This script compares two DNS zone files (e.g., before and after a migration).  
It canonicalizes the zone files, removes Microsoft DNS timestamps and ignorable records, then uses `ldns-compare-zones` to generate a clean, auditable diff.  
Logs are written to `dns_diff_tool.log`.

</details>

<details>
  <summary>dns_health_check</summary>

* [dns_health_check.sh](dns_health_check/dns_health_check.sh)

**Description**

A comprehensive DNS health check script that validates delegation, authoritative servers, SOA records, DNSSEC, mail-related DNS entries, reachability, and network configuration for a given domain.

</details>

<details>
  <summary>dns_review</summary>

* [dns_review.sh](dns_review/dns_review.sh)

**Description**

This script reviews and validates a BIND-style DNS configuration.  
It takes a `named.conf` and associated zone files, flattens the configuration, checks syntax and zones, removes Microsoft DNS timestamps, and canonicalizes zone files.  
The goal is to provide a clear overview of configuration health and identify issues.

</details>

<details>
  <summary>dns_zip2csv</summary>

* [dns_zip2csv.sh](dns_zip2csv/dns_zip2csv.sh)

**Description**

This script processes **ZIP archives** containing DNS export files and generates a **merged CSV summary** of all discovered zones.

</details>

<details>
  <summary>dublicated_entries</summary>

* [dublicated_entries.sh](dublicated_entries/dublicated_entries.sh)

**Description**

This script validates DNS zone files for **duplicate entries**:  
- Hosts mapped to multiple IP addresses.  
- IP addresses mapped to multiple hosts.  

</details>

<details>
  <summary>export_dhcpd</summary>

* [export_dhcpd.sh](export_dhcpd/export_dhcpd.sh)

**Description**

This script extracts subnet configurations from an `dhcpd.conf` file based on a provided list of IPv4 CIDR ranges.  
It validates prerequisites, cleans the input, processes the configuration, and produces a resulting configuration file with only the desired ranges.

</details>

<details>
  <summary>export_ms-dns-dhcp</summary>

* [export_ms-dns-dhcp.ps1](export_ms-dns-dhcp/export_ms-dns-dhcp.ps1)

**Description**

This PowerShell script exports both **DNS and DHCP configuration** from a Microsoft Windows Server and packages the results into a ZIP archive for handover, backup, or migration purposes.

</details>

<details>
  <summary>extract_ms_zip</summary>

* [extract_ms_zip.sh](extract_ms_zip/extract_ms_zip.sh)

**Description**

This script extracts Microsoft DNS/DHCP export archives that match the naming pattern:
```
MS-DNS-DHCP_*.zip
```
(case-insensitive).  
Each archive is extracted into its own subfolder under an `exports/` directory, and the script reports whether the extracted content contains a `dbs/` folder (commonly used for DNS zone files).

</details>

<details>
  <summary>find_zone_duplicates</summary>

* [find_zone_duplicates.py](find_zone_duplicates/find_zone_duplicates.py)

**Description**

This Python script detects duplicated authoritative DNS zones (Zone Type: Primary/master) defined across multiple servers.  
It optionally filters out reverse zones and outputs a CSV containing all duplicate authoritative zone definitions.

</details>

<details>
  <summary>flush_jnl</summary>

* [flush_jnl.sh](flush_jnl/flush_jnl.sh)

**Description**

This script starts a temporary **BIND (named)** instance using the local `named.conf`,  
executes `rndc sync -clean` to flush all **.jnl journal files** into their corresponding **.db zone files**,  
and then shuts the server down cleanly.

</details>

<details>
  <summary>gen_named</summary>

* [gen_named.sh](gen_named/gen_named.sh)

**Description**

This script generates a minimal `named.conf` configuration file for BIND by scanning a directory of DNS zone files.  
For each zone file, it extracts the zone name from the SOA record and creates a corresponding `zone` block.

</details>

<details>
  <summary>jumper</summary>

* [jumper.sh](jumper/jumper.sh)

**Description**

Interactive SSH helper script that allows you to select a server from a list and connect to it.  
It validates input, checks connectivity, and logs all actions. Useful as a "jumper" or "bastion" tool for quickly connecting to servers from a predefined inventory.

</details>

<details>
  <summary>merge_csvs</summary>

* [merge_csvs.sh](merge_csvs/merge_csvs.sh)

**Description**

This script merges multiple **CSV files** from a given directory into one consolidated, timestamped CSV file.  
It keeps only the header from the first file, merges the rest in sorted order, and provides statistics on line counts.  
If the `ssconvert` tool is available, it also generates an Excel `.xls` version of the merged file.

</details>

<details>
  <summary>named2csv</summary>

* [named2csv.py](named2csv/named2csv.py)

**Description**

This Python script parses a BIND `named.conf` configuration file and extracts zone details into a structured CSV file.  
It captures zone name, type, associated IPs, dynamic update settings, and any global forwarders defined in the `options` block.

</details>

<details>
  <summary>nslookup_bulk</summary>

* [nslookup_bulk.bat](nslookup_bulk/nslookup_bulk.bat)

**Description**

Batch script for Windows to perform **bulk DNS lookups**.  
It iterates through a list of FQDNs, queries a specified DNS server for a given record type using `nslookup`, and saves results to files.

</details>

<details>
  <summary>ptr_clean-up</summary>

* [ptr_clean-up.sh](ptr_clean-up/ptr_clean-up.sh)

**Description**

This script validates and cleans up **reverse DNS (PTR) zones** in a BIND-style DNS setup.  
It ensures that configuration and zone files are consistent, removes Microsoft DNS timestamps, canonicalizes the zones, and logs all actions.

</details>

<details>
  <summary>qip_named_normalizer</summary>

* [qip_named_normalizer.sh](qip_named_normalizer/qip_named_normalizer.sh)

**Description**

This script prepares a **QIP-exported BIND/named configuration file** for validation and normalization.  
QIP configurations often include unsupported or environment-specific directives that can break `named-checkconf`.  
The script filters those directives, then generates a fully expanded normalized configuration.

</details>

<details>
  <summary>reverse_from_network</summary>

* [reverse_from_network.sh](reverse_from_network/reverse_from_network.sh)

**Description**

This script converts a list of IPv4 networks in CIDR notation into corresponding **reverse DNS zones** (`in-addr.arpa`).  
It supports `/8`, `/16`, and `/24` networks and generates a list of reverse zones.

</details>

<details>
  <summary>run_all_servers</summary>

* [run_all_servers.sh](run_all_servers/run_all_servers.sh)

**Description**

This script automates running **SSH commands** or performing **SCP file transfers** across multiple servers from a list.  
It supports batch execution with optional parallelization, input validation, and logging.

</details>

<details>
  <summary>server_prefix_groups</summary>

* [server_prefix_groups.py](server_prefix_groups/server_prefix_groups.py)

**Description**

This Python script identifies DNS zones whose **Primary/master** servers fall into **different naming groups**, where a "group" is defined by the alpha-prefix (letters before the first digit in the server name).

</details>

<details>
  <summary>sort_list_of_domains</summary>

* [sort_list_of_domains.sh](sort_list_of_domains/sort_list_of_domains.sh)

**Description**

This script processes and sorts a list of DNS zones.  
It handles both **forward zones** (e.g. `example.com`) and **reverse zones** in CIDR notation (e.g. `192.168.1.0/24`).  
Reverse zones are converted into the correct `in-addr.arpa` format, and the combined list of zones is sorted hierarchically by domain labels.  
The cleaned, normalized, and sorted list is written to a result file.

</details>

<details>
  <summary>umlauts</summary>

* [umlauts.sh](umlauts/umlauts.sh)

**Description**

This script searches for files matching a given pattern under a specified directory, repairs double-encoded UTF-8 text, and transliterates German umlauts into ASCII equivalents.

</details>

<details>
  <summary>zone_from_zips</summary>

* [zone_from_zips.sh](zone_from_zips/zone_from_zips.sh)

**Description**

This script searches through a directory of ZIP archives, looks for a **specific zone file** inside each archive,  
and extracts the matching files into a `_working/` subdirectory.  

</details>

<details>
  <summary>zone_version_diff</summary>

* [zone_version_diff.py](zone_version_diff/zone_version_diff.py)

**Description**

This Python script compares multiple **versions of DNS zone files** in a directory.  
It groups zone files by filename prefix, parses records with **dnspython**, and performs pairwise diffs between versions.  

</details>

---