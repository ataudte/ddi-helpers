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
  <summary>ascii_cleaner</summary>

* [ascii_cleaner.py](ascii_cleaner/ascii_cleaner.py)

Convert flat export files to ASCII for legacy import tools. Processes all files with a given extension in a target folder, preferring `iconv` UTF‑8→ASCII with transliteration, then `iconv` with `//ignore`, and finally a Python fallback that applies a German transliteration map (Ä→Ae, Ö→Oe, Ü→Ue, ä→ae, ö→oe, ü→ue, ß→ss). Cleaned files go to `ascii_cleaned/`; detailed per‑file logs for issues go to `ascii_cleaned/logs/`.

</details>

<details>
  <summary>backup_ipctrl</summary>

* [backup_ipctrl.ps1](backup_ipctrl/backup_ipctrl.ps1)

This PowerShell script creates a **MySQL backup** of the BlueCat IPControl database.  
It runs `mysqldump.exe`, saves the export as a `.sql` file, compresses it into a `.zip`, and manages retention by deleting old backups.

</details>

<details>
  <summary>bam_health</summary>

* [bam_health.sh](bam_health/bam_health.sh)

This script runs a **health check** on a BlueCat Address Manager (BAM) server.  
It validates prerequisites, gathers system information, checks the application/database state,
and logs results into a timestamped log file.

</details>

<details>
  <summary>bdds_export</summary>

* [bdds_export.sh](bdds_export/bdds_export.sh)

This script collects DNS and DHCP configuration data from a **BlueCat DNS/DHCP Server (BDDS)** and archives it into a compressed `.tar.gz` file.  
It is intended for backup, migration, or troubleshooting scenarios.

</details>

<details>
  <summary>bdds_health</summary>

* [bdds_health.sh](bdds_health/bdds_health.sh)

Health check script for **BlueCat DNS/DHCP Server (BDDS)**.  
It validates prerequisites, collects system and service status (CPU, memory, filesystem, processes), inspects **DNS (named)** and **DHCP (dhcpd)** services, summarizes DHCP lease states, and records BlueCat software version and applied patches.  
All results are written to a timestamped logfile on the BDDS itself.

</details>

<details>
  <summary>check_dhcp-options</summary>

* [check_dhcp-options.sh](check_dhcp-options/check_dhcp-options.sh)

This script validates a **Microsoft DHCP XML export** and checks whether each DHCP scope has all critical DHCP options defined.  
It reports any missing options per scope.

</details>

<details>
  <summary>check_dhcp_failover</summary>

* [check_dhcp_failover.sh](check_dhcp_failover/check_dhcp_failover.sh)

This script checks the **DHCP failover state** on a BlueCat DNS/DHCP Server (BDDS).  
It extracts credentials and association details from the DHCP configuration, connects with `omshell`, and reports both local and partner failover states.

</details>

<details>
  <summary>check_ports</summary>

* [check_ports.sh](check_ports/check_ports.sh)

This script checks connectivity for a set of predefined ports across multiple servers provided in an input list.  
It validates TCP/UDP services commonly used in DNS, DHCP, NTP, SNMP, and related applications.  
Results are logged to both the console (with color-coded output) and a timestamped logfile.

</details>

<details>
  <summary>check_xmls</summary>

* [check_xmls.sh](check_xmls/check_xmls.sh)

This script scans a given directory for `.zip` files and verifies whether each contains expected DHCP and DNS XML configuration files (`*_dhcp.xml`, `*_dns-config.xml`).
It logs missing files and errors into separate CSV reports.

</details>

<details>
  <summary>check_zone</summary>

* [check_zone.sh](check_zone/check_zone.sh)

This script performs a **sanity check** on a DNS zone file.  
It can inject a missing `$ORIGIN` directive if needed, runs BIND’s `named-checkzone`, and saves results into a report file.

</details>

<details>
  <summary>collect_health_check</summary>

* [collect_health_check.sh](collect_health_check/collect_health_check.sh)

This script automates the collection of health check data from a **BlueCat deployment**, including both **BlueCat DNS/DHCP Servers (BDDS)** and **BlueCat Address Manager (BAM)**.

</details>

<details>
  <summary>compare_pattern</summary>

* [compare_pattern.sh](compare_pattern/compare_pattern.sh)

This script compares two files by extracting all lines that contain a given search pattern.  
It normalizes the matches and produces multiple output files, including raw matches, unique matches, common lines, and diffs.

</details>

<details>
  <summary>compare_zone_variants</summary>

* [compare_zone_variants.sh](compare_zone_variants/compare_zone_variants.sh)

Compare **DNS zone file variants** that share the **same filename** but live in **different folders** under a root path.  
The script gathers all matching files (by filename pattern), de‑duplicates identical content, cleans MS‑DNS artifacts, **canonicalizes** them with `named-checkzone`, normalizes records (ignore SOA, ignore TTL, lowercase), and then compares **variants of the same basename**.  
Differences are logged; non‑identical canonical variants are preserved for review.

</details>

<details>
  <summary>convert_netmask-cidr</summary>

* [convert_netmask-cidr.sh](convert_netmask-cidr/convert_netmask-cidr.sh)

This script converts between **CIDR notation** (e.g., `/24`) and **netmask notation** (e.g., `255.255.255.0`) within a CSV file.  

</details>

<details>
  <summary>count_active_leases</summary>

* [count_active_leases.sh](count_active_leases/count_active_leases.sh)

This script parses the ISC DHCP **leases file** and counts:
- **Active leases (unique IPs)**  
- **Active clients (unique MAC addresses)**  

</details>

<details>
  <summary>csv_matcher</summary>

* [csv_matcher.sh](csv_matcher/csv_matcher.sh)

This script filters rows from a data CSV into **match** and **miss** files based on wildcard patterns stored in a values CSV.  
It supports per-file delimiters, case-insensitive matching by default, and `*` wildcards for prefix, suffix, and substring matches.

</details>

<details>
  <summary>ddns_utils</summary>

* [ddns_clean-up.sh](ddns_utils/ddns_clean-up.sh)
* [ddns_update.sh](ddns_utils/ddns_update.sh)

Two shell scripts to **create/update** and **remove** DNS records by feeding `nsupdate` with commands derived from a simple CSV-like input file.

</details>

<details>
  <summary>dependent_records</summary>

* [dependent_records.sh](dependent_records/dependent_records.sh)

This script identifies **dependent DNS records** across multiple zones.  
It performs zone transfers (AXFR) from the primary nameserver of each zone, then compares the transferred data with a given list of records to find dependencies.  
Results are written into separate dependency reports for each zone.

</details>

<details>
  <summary>dhcp-xml_review</summary>

* [dhcp-xml_review.py](dhcp-xml_review/dhcp-xml_review.py)

This Python script parses a **Microsoft DHCP XML export** and generates multiple structured CSV files for analysis.  
It extracts server-wide options, scopes, reservations, and class assignments (VendorClass/UserClass).  

</details>

<details>
  <summary>dhcpd_subnet-list</summary>

* [dhcpd_subnet-list.sh](dhcpd_subnet-list/dhcpd_subnet-list.sh)

This script extracts all **subnet definitions** from an ISC DHCP configuration file (`dhcpd.conf`) and exports them into a CSV file.  
It includes the subnet address, subnet mask, and CIDR notation.

</details>

<details>
  <summary>dig_bulk</summary>

* [dig_bulk.sh](dig_bulk/dig_bulk.sh)

This script performs bulk DNS queries against a list of servers for a list of zones.  
It checks for the presence of **SOA, NS, and A records** for each zone on each server, logs the results, and reports whether queries succeeded or failed.

</details>

<details>
  <summary>dig_dump</summary>

* [dig_dump.sh](dig_dump/dig_dump.sh)

This script runs a `dig` DNS query against a specified DNS server while simultaneously capturing the associated DNS traffic with `tcpdump`.  
The result is a `.pcap` file for later analysis (e.g. in Wireshark) and a tcpdump log file.

</details>

<details>
  <summary>dns_cutover</summary>

* [dns_cutover.ps1](dns_cutover/dns_cutover.ps1)
* [dns_cutover_restore.ps1](dns_cutover/dns_cutover_restore.ps1)

PowerShell script to automate a **DNS cutover** on Microsoft Windows DNS Server.  
It reads a CSV with zone configuration and global settings, creates a full backup of the current DNS state, applies changes (secondary zones, forwarders, removals), and logs all actions for audit/handover.  

</details>

<details>
  <summary>dns_diff_tool</summary>

* [dns_diff_tool.sh](dns_diff_tool/dns_diff_tool.sh)

This script compares two DNS zone files (e.g., before and after a migration).  
It canonicalizes the zone files, removes Microsoft DNS timestamps and ignorable records, then uses `ldns-compare-zones` to generate a clean, auditable diff.  
Logs are written to `dns_diff_tool.log`.

</details>

<details>
  <summary>dns_health_check</summary>

* [dns_health_check.sh](dns_health_check/dns_health_check.sh)

A comprehensive DNS health check script that validates delegation, authoritative servers, SOA records, DNSSEC, mail-related DNS entries, reachability, and network configuration for a given domain.

</details>

<details>
  <summary>dns_review</summary>

* [dns_review.sh](dns_review/dns_review.sh)

This script reviews and validates a BIND-style DNS configuration.  
It takes a `named.conf` and associated zone files, flattens the configuration, checks syntax and zones, removes Microsoft DNS timestamps, and canonicalizes zone files.  
The goal is to provide a clear overview of configuration health and identify issues.

</details>

<details>
  <summary>dns_zip2csv</summary>

* [dns_zip2csv.sh](dns_zip2csv/dns_zip2csv.sh)

This script processes **ZIP archives** containing DNS export files and generates a **merged CSV summary** of all discovered zones.

</details>

<details>
  <summary>dublicated_entries</summary>

* [dublicated_entries.sh](dublicated_entries/dublicated_entries.sh)

This script validates DNS zone files for **duplicate entries**:  
- Hosts mapped to multiple IP addresses.  
- IP addresses mapped to multiple hosts.  

</details>

<details>
  <summary>export_dhcpd</summary>

* [export_dhcpd.sh](export_dhcpd/export_dhcpd.sh)

This script extracts subnet configurations from an `dhcpd.conf` file based on a provided list of IPv4 CIDR ranges.  
It validates prerequisites, cleans the input, processes the configuration, and produces a resulting configuration file with only the desired ranges.

</details>

<details>
  <summary>export_ms-dns-dhcp</summary>

* [export_ms-dns-dhcp.ps1](export_ms-dns-dhcp/export_ms-dns-dhcp.ps1)

This PowerShell script exports both **DNS and DHCP configuration** from a Microsoft Windows Server and packages the results into a ZIP archive for handover, backup, or migration purposes.

</details>

<details>
  <summary>extract_ms-dhcp_macs</summary>

* [extract_ms-dhcp_macs.py](extract_ms-dhcp_macs/extract_ms-dhcp_macs.py)

This script extracts MAC-to-IP mappings from a Microsoft DHCP Server XML export.  
It generates a complete list of all MACs and their associated IPs and a filtered list showing only MACs with multiple IPs.

</details>

<details>
  <summary>extract_ms_zip</summary>

* [extract_ms_zip.sh](extract_ms_zip/extract_ms_zip.sh)

This script extracts Microsoft DNS/DHCP export archives that match the naming pattern `MS-DNS-DHCP_*.zip` (case-insensitive).
Each archive is extracted into its own subfolder under an `exports/` directory, and the script reports whether the extracted content contains a `dbs/` folder (commonly used for DNS zone files).

</details>

<details>
  <summary>file_merger</summary>

* [file_merger.sh](file_merger/file_merger.sh)

This script merges all files with a given suffix/extension from a specified directory into a single consolidated file.  
The output file is named after the directory basename plus the chosen suffix.

</details>

<details>
  <summary>find_zone_duplicates</summary>

* [find_zone_duplicates.py](find_zone_duplicates/find_zone_duplicates.py)

This Python script detects duplicated authoritative DNS zones (Zone Type: Primary/master) defined across multiple servers.  
It optionally filters out reverse zones and outputs a CSV containing all duplicate authoritative zone definitions.

</details>

<details>
  <summary>flush_jnl</summary>

* [flush_jnl.sh](flush_jnl/flush_jnl.sh)

This script starts a temporary **BIND (named)** instance using the local `named.conf`,  
executes `rndc sync -clean` to flush all **.jnl journal files** into their corresponding **.db zone files**,  
and then shuts the server down cleanly.

</details>

<details>
  <summary>gen_dummy_ipam</summary>

* [gen_dummy_ipam.sh](gen_dummy_ipam/gen_dummy_ipam.sh)

This script generates a **CSV file** containing all subnets derived from a given **CIDR network** and a target **subnet mask size**.  

</details>

<details>
  <summary>gen_named</summary>

* [gen_named.sh](gen_named/gen_named.sh)

This script generates a minimal `named.conf` configuration file for BIND by scanning a directory of DNS zone files.  
For each zone file, it extracts the zone name from the SOA record and creates a corresponding `zone` block.

</details>

<details>
  <summary>get_ipctrl_logs</summary>

* [get_ipctrl_logs.sh](get_ipctrl_logs/get_ipctrl_logs.sh)

This script collects all **IPControl log files** (`*.log*`) from the default installation directory (`/opt/incontrol`) and packages them into a compressed tarball for troubleshooting or support purposes.

</details>

<details>
  <summary>get_ldap_groups</summary>

* [get_ldap_groups.pl](get_ldap_groups/get_ldap_groups.pl)

A Perl script that connects to an **LDAP/Active Directory** server, searches for a given user, and prints all groups (`memberOf`) the user belongs to.

</details>

<details>
  <summary>get_vendor-classes</summary>

* [get_vendor-classes.sh](get_vendor-classes/get_vendor-classes.sh)

This script analyzes a **Microsoft DHCP XML export** and extracts information about **Vendor Classes** and their DHCP options.  

</details>

<details>
  <summary>ipctrl_importer</summary>

* [ipctrl_importer.sh](ipctrl_importer/ipctrl_importer.sh)

This script is a wrapper for running **IPControl CLI imports** with CSV files.  
It validates input, runs the import, generates reject/error files, and reports runtime duration.

</details>

<details>
  <summary>ipctrl_restore-reset</summary>

* [ipctrl_restore-reset.sh](ipctrl_restore-reset/ipctrl_restore-reset.sh)

This script restores an IPControl database from a provided SQL dump (packaged as a `.zip` file).  
It unpacks the SQL, stops the InControl service, starts MySQL, and loads the SQL dump into the database.

</details>

<details>
  <summary>jnl_clean-up</summary>

* [jnl_clean-up.sh](jnl_clean-up/jnl_clean-up.sh)

This script safely removes **BIND journal (.jnl) files** from a BlueCat DNS server environment.  
It stops the `named` service, backs up all `.jnl` files to a temporary folder, and deletes them from the live configuration directory.

</details>

<details>
  <summary>jumper</summary>

* [jumper.sh](jumper/jumper.sh)

Interactive SSH helper script that allows you to select a server from a list and connect to it.  
It validates input, checks connectivity, and logs all actions. Useful as a "jumper" or "bastion" tool for quickly connecting to servers from a predefined inventory.

</details>

<details>
  <summary>merge_csvs</summary>

* [merge_csvs.sh](merge_csvs/merge_csvs.sh)

This script merges multiple **CSV files** from a given directory into one consolidated, timestamped CSV file.  
It keeps only the header from the first file, merges the rest in sorted order, and provides statistics on line counts.  
If the `ssconvert` tool is available, it also generates an Excel `.xls` version of the merged file.

</details>

<details>
  <summary>named2csv</summary>

* [named2csv.py](named2csv/named2csv.py)

This Python script parses a BIND `named.conf` configuration file and extracts zone details into a structured CSV file.  
It captures zone name, type, associated IPs, dynamic update settings, and any global forwarders defined in the `options` block.

</details>

<details>
  <summary>named_collection</summary>

* [named_collection.sh](named_collection/named_collection.sh)

This script recursively searches for **named.conf** files under a given root directory,  
extracts zone information, and generates an overview of all DNS zones and their associated files.  

</details>

<details>
  <summary>normalise_zones</summary>

* [normalise_zones.sh](normalise_zones/normalise_zones.sh)

This script validates and **normalizes DNS zone files** listed in a `named.conf`.  
It separates forward and reverse zones, cleans Microsoft DNS artifacts, canonicalizes each zone with `named-checkzone`, and validates the presence of forward records.  

</details>

<details>
  <summary>nslookup_bulk</summary>

* [nslookup_bulk.bat](nslookup_bulk/nslookup_bulk.bat)

Batch script for Windows to perform **bulk DNS lookups**.  
It iterates through a list of FQDNs, queries a specified DNS server for a given record type using `nslookup`, and saves results to files.

</details>

<details>
  <summary>parse_ms-dns_xml</summary>

* [parse_ms-dns_xml.py](parse_ms-dns_xml/parse_ms-dns_xml.py)

Parses a Microsoft DNS XML export file and extracts a **quick overview** of a single server's configuration.
Extracts Server name, Zone names, Master server IPs, and Global forwarders. Intended as a lightweight helper script for analyzing a **single** XML file.

</details>

<details>
  <summary>ptr_clean-up</summary>

* [ptr_clean-up.sh](ptr_clean-up/ptr_clean-up.sh)

This script validates and cleans up **reverse DNS (PTR) zones** in a BIND-style DNS setup.  
It ensures that configuration and zone files are consistent, removes Microsoft DNS timestamps, canonicalizes the zones, and logs all actions.

</details>

<details>
  <summary>pw_check</summary>

* [pw_check.sh](pw_check/pw_check.sh)

This script verifies which of up to **three provided passwords** are valid for logging into a list of BlueCat DNS/DHCP Servers (BDDS) over SSH.  
It iterates through servers from a file, attempts password authentication, and logs the results.

</details>

<details>
  <summary>pw_mgmt</summary>

* [pw_mgmt.sh](pw_mgmt/pw_mgmt.sh)

Bulk **password rotation** for BlueCat DNS/DHCP Servers (BDDS).  
For each BDDS listed in an input file, the script:
1) Validates SSH access with the **current root password**.  
2) Connects via SSH and runs `passwd -q <user>` non‑interactively to set a **new password** for the target user.  
3) If the target user is `root`, it **re‑validates** SSH with the **new** password.  
All steps are logged.

</details>

<details>
  <summary>qip_named_normalizer</summary>

* [qip_named_normalizer.sh](qip_named_normalizer/qip_named_normalizer.sh)

This script prepares a **QIP-exported BIND/named configuration file** for validation and normalization.  
QIP configurations often include unsupported or environment-specific directives that can break `named-checkconf`.  
The script filters those directives, then generates a fully expanded normalized configuration.

</details>

<details>
  <summary>qip_overview</summary>

* [qip_overview.py](qip_overview/qip_overview.py)

Generates a compact, operator‑friendly overview of a QIP export (QEF files). It parses the export directory and writes CSV overviews for zones, subnets (v4/v6), ranges, and more.
DHCP pools and reservations are derived directly from `obj_prof.qef` to match production behavior, with numeric sorting and CIDR‑aware metadata.

</details>

<details>
  <summary>random_nsupdate</summary>

* [random_nsupdate.dh](random_nsupdate/random_nsupdate.dh)

This script performs randomized **dynamic DNS updates** using the `nsupdate` utility.  
It continuously generates random hostnames and IPv4 addresses and adds them to a specified DNS zone on a given server for a defined duration.

</details>

<details>
  <summary>replace_column</summary>

* [replace_column.sh](replace_column/replace_column.sh)

This script replaces all values in a specified **column of a CSV file** with a new value.  
The modified data is saved into a new CSV file with the replacement value embedded in the filename.

</details>

<details>
  <summary>reverse_from_network</summary>

* [reverse_from_network.sh](reverse_from_network/reverse_from_network.sh)

This script converts a list of IPv4 networks in CIDR notation into corresponding **reverse DNS zones** (`in-addr.arpa`).  
It supports `/8`, `/16`, and `/24` networks and generates a list of reverse zones.

</details>

<details>
  <summary>run_all_servers</summary>

* [run_all_servers.sh](run_all_servers/run_all_servers.sh)

This script automates running **SSH commands** or performing **SCP file transfers** across multiple servers from a list.  
It supports batch execution with optional parallelization, input validation, and logging.

</details>

<details>
  <summary>search_datarake</summary>

* [search_datarake.sh](search_datarake/search_datarake.sh)

This script searches through `.tgz` archives in a given input directory for a **search string** within `daemon.log` files (including rotated and compressed versions).  
It extracts only the matching log files into a `matched_logs` directory for further analysis, while cleaning up temporary data.

</details>

<details>
  <summary>server_prefix_groups</summary>

* [server_prefix_groups.py](server_prefix_groups/server_prefix_groups.py)

This Python script identifies DNS zones whose **Primary/master** servers fall into **different naming groups**, where a "group" is defined by the alpha-prefix (letters before the first digit in the server name).

</details>

<details>
  <summary>sort_list_of_domains</summary>

* [sort_list_of_domains.sh](sort_list_of_domains/sort_list_of_domains.sh)

This script processes and sorts a list of DNS zones.  
It handles both **forward zones** (e.g. `example.com`) and **reverse zones** in CIDR notation (e.g. `192.168.1.0/24`).  
Reverse zones are converted into the correct `in-addr.arpa` format, and the combined list of zones is sorted hierarchically by domain labels.  
The cleaned, normalized, and sorted list is written to a result file.

</details>

<details>
  <summary>split_horizon_dns</summary>

* [split_horizon_dns.sh](split_horizon_dns/split_horizon_dns.sh)

This script compares two **BIND configuration files** (`named.conf` style) to identify **zones defined in both files**.  
It then extracts and compares zone details, highlighting when the **zone type** (e.g., `master`, `slave`, `stub`, `forward`) matches between the two.

</details>

<details>
  <summary>umlauts</summary>

* [umlauts.sh](umlauts/umlauts.sh)

This script searches for files matching a given pattern under a specified directory, repairs double-encoded UTF-8 text, and transliterates German umlauts into ASCII equivalents.

</details>

<details>
  <summary>zone_from_zips</summary>

* [zone_from_zips.sh](zone_from_zips/zone_from_zips.sh)

This script searches through a directory of ZIP archives, looks for a **specific zone file** inside each archive,  
and extracts the matching files into a `_working/` subdirectory.  

</details>

<details>
  <summary>zone_version_diff</summary>

* [zone_version_diff.py](zone_version_diff/zone_version_diff.py)

This Python script compares multiple **versions of DNS zone files** in a directory.  
It groups zone files by filename prefix, parses records with **dnspython**, and performs pairwise diffs between versions.  

</details>

<details>
  <summary>zones_from_dotted_hosts</summary>

* [zone_to_subzones.sh](zones_from_dotted_hosts/zone_to_subzones.sh)
* [zones_from_dotted_hosts.sh](zones_from_dotted_hosts/zones_from_dotted_hosts.sh)

These two scripts work together to analyze and split DNS zone files into **subzones**.

</details>

---