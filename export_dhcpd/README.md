# export_dhcpd.sh

## Description
This script extracts subnet configurations from an `dhcpd.conf` file based on a provided list of IPv4 CIDR ranges.  
It validates prerequisites, cleans the input, processes the configuration, and produces a resulting configuration file with only the desired ranges.

All steps are logged to a timestamped log file.

---

## Usage
```bash
./export_dhcpd.sh <ip-ranges> <dhcpd.conf>
```

- **ip-ranges**: File containing IPv4 CIDR ranges, one per line.  
- **dhcpd.conf**: ISC DHCP configuration file.  

Example:
```bash
./export_dhcpd.sh ranges.csv dhcpd.conf
```

---

## Features
- Validates prerequisites (`rgxg`).  
- Sorts and deduplicates the list of ranges.  
- Cleans the ranges to ensure valid CIDR format.  
- Flattens the DHCP config file into a single line per subnet.  
- Filters the config file using regex patterns generated from the CIDR ranges.  
- Produces a final `*_result.config` file with only the matching subnets.  
- Removes intermediate files after processing.  

---

## Input / Output
- **Input:**  
  - List of ranges: `ranges.csv`  
  - Config file: `dhcpd.conf`  

- **Output (generated in the same folder):**  
  - `<ranges>_sort.csv` (sorted ranges)  
  - `<ranges>_clean.csv` (validated ranges)  
  - `<config>_flat.config` (flattened config)  
  - `<config>_filter.config` (filtered config)  
  - `<config>_sort.config` (sorted/unique config)  
  - `<config>_result.config` (final output)  
  - `export_dhcpd_<timestamp>.log` (log file)  

Intermediate files are deleted automatically after the result is created.

---

## Requirements
- Bash (`/usr/local/bin/bash`)  
- Tools:
  - `rgxg` (to generate regexes from CIDR ranges)  
  - `egrep`, `sed`, `sort`, `uniq`  

---

## Notes
- Only valid IPv4 CIDR ranges are processed.  
- Designed for cleaning and exporting relevant subnet sections from large ISC DHCP configurations.  
- Logs contain detailed debug and error messages.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
