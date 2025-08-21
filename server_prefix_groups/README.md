# server_prefix_groups.py

## Description
This Python script identifies DNS zones whose **Primary/master** servers fall into **different naming groups**, where a "group" is defined by the alpha-prefix (letters before the first digit in the server name).

This helps flag inconsistent naming conventions in DNS infrastructures.

---

## Usage
```bash
python server_prefix_groups.py <zones.csv>
```

- **zones.csv**: Input CSV file (headers optional).  

Example:
```bash
python server_prefix_groups.py dns_zones.csv
```

---

## Features
- Accepts CSV with or without headers.  
- By default:
  - **Column B** → Server name  
  - **Column D** → Zone name  
  - **Column E** → Zone type  
- Filters zones:
  - Keeps only **Primary/master** zones (case-insensitive).  
  - Ignores reverse zones (`*.in-addr.arpa`, `*.ip6.arpa`) and AD-specific zones (`_msdcs.*`, `_sites.*`, `_tcp.*`, `_udp.*`, `forestdnszones.*`, `domaindnszones.*`, etc.).  
  - Drops zones with fewer rows than `MIN_ROWS_PER_ZONE` (default: 2).  
- Groups servers by alpha-prefix (e.g., `ns1` → `ns`, `dns03` → `dns`).  
- Flags zones where multiple groups exist.  
- Outputs a CSV file with flagged zones.  

---

## Input / Output
- **Input CSV columns (flexible mapping):**
  - `Server` (or synonyms like `servername`, `host`, etc.)  
  - `Zone Name`  
  - `Zone Type`  

- **Output:**  
  - `<input_stem>_flagged-zones.csv`  
  - Columns:
    - `primary_zone` → Zone name  
    - `server_names` → Comma-separated list of servers with inconsistent naming  

Console output:
```
Wrote dns_zones_flagged-zones.csv (5 zones)
```

---

## Requirements
- Python 3  
- Libraries:
  - `pandas`  

Install with:
```bash
pip install pandas
```

---

## Notes
- Matching is case-insensitive, but output preserves original casing.  
- Adjust `IGNORE_ZONE_PATTERNS` or `MIN_ROWS_PER_ZONE` in the script as needed.  
- Useful for auditing DNS environments with multiple naming standards.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
