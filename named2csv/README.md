# named2csv.py

## Description
This Python script parses a BIND `named.conf` configuration file and extracts zone details into a structured CSV file.  
It captures zone name, type, associated IPs, dynamic update settings, and any global forwarders defined in the `options` block.

---

## Usage
```bash
python named2csv.py <named.conf> [output.csv]
```

- **named.conf**: Input BIND configuration file.  
- **output.csv**: Optional output filename (default: same basename as input with `.csv` extension).  

Examples:
```bash
python named2csv.py /etc/bind/named.conf
python named2csv.py /etc/bind/named.conf zones.csv
```

---

## Features
- Parses `zone` blocks from BIND configuration.  
- Extracts:
  - **Zone Name**
  - **Zone Type** (`master`, `slave`, `forward`, `stub`)
  - **Master server IPs** (from `masters`, `forwarders`, or `allow-transfer`)  
  - **Dynamic update settings** (`allow-update`)  
- Detects **global forwarders** from the `options` block.  
- Outputs CSV with one row per zone.  

---

## Input / Output
- **Input:**  
  - A valid `named.conf` or include file with zone definitions.  

- **Output CSV fields:**  
  - `XML File` (empty placeholder)  
  - `Server Name` (basename of input file)  
  - `Global Forwarders`  
  - `Zone Name`  
  - `Zone Type`  
  - `ReplicationScope` (currently empty)  
  - `IsShutdown` (currently empty)  
  - `DynamicUpdate` (from `allow-update`)  
  - `Zone-Type IPs` (masters/forwarders/transfer IPs depending on zone type)  

---

## Requirements
- Python 3  
- Standard library only (no external dependencies).  

---

## Notes
- The script only parses `zone` blocks and `options` for forwarders.  
- Some fields (`ReplicationScope`, `IsShutdown`) are placeholders for compatibility with other systems and remain empty.  
- Intended for migration, documentation, or auditing of BIND configurations.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
