# find_zone_duplicates.py

## Description
This Python script detects duplicated authoritative DNS zones (Zone Type: Primary/master) defined across multiple servers.  
It optionally filters out reverse zones and outputs a CSV containing all duplicate authoritative zone definitions.

---

## Usage
```bash
./find_zone_duplicates.py <input_csv_file>
```

- **input_csv_file**: CSV file containing DNS zone data (e.g. export from IPAM/DDI).  

Example:
```bash
./find_zone_duplicates.py zones.csv
```

---

## Features
- Normalizes and filters for authoritative zones (`Primary` / `master`).  
- Optionally ignores reverse zones (`*.in-addr.arpa`, `*.ip6.arpa`) — controlled via the global toggle:
  ```python
  IGNORE_REVERSE_ZONES = True
  ```
- Groups zones by name and detects if they are defined on more than one server.  
- Outputs detailed CSV with all matching rows for duplicated zones.  
- Provides a summary (count of duplicated zones and rows).  

---

## Input / Output
- **Input:** CSV file with at least these columns:
  - `Zone Name`
  - `Zone Type`
  - `Server Name`  

- **Output:** A new CSV file in the same directory as input:
  ```
  <input_stem>_duplicates.csv
  ```
  containing only duplicated authoritative zones, sorted by Zone Name and Server Name.  

- **Console Output:**  
  - Count of duplicated zones  
  - Count of authoritative rows  
  - Output filename  

---

## Requirements
- Python 3  
- Libraries:
  - `pandas`  

Install dependencies if needed:
```bash
pip install pandas
```

---

## Notes
- The script assumes a flat CSV with zone metadata.  
- To include reverse zones, set `IGNORE_REVERSE_ZONES = False`.  
- Useful for identifying misconfigurations or overlaps in DDI/DNS infrastructures.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
