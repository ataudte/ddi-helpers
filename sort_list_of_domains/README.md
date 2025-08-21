# sort_list_of_domains.sh

## Description
This script processes and sorts a list of DNS zones.  
It handles both **forward zones** (e.g. `example.com`) and **reverse zones** in CIDR notation (e.g. `192.168.1.0/24`).  
Reverse zones are converted into the correct `in-addr.arpa` format, and the combined list of zones is sorted hierarchically by domain labels.  
The cleaned, normalized, and sorted list is written to a result file.

---

## Usage
Provide a file with a list of zones (forward and/or reverse):  
```bash
./sort_list_of_domains.sh zones.txt
```

Example `zones.txt`:
```
"example.com"
"sub.example.org"
"192.168.1.0/24"
"10.0.0.0/8"
```

---

## Requirements
- Bash (`/bin/bash`)
- Linux utilities:
  - `sed`, `awk`, `egrep`, `sort`, `wc`

---

## Input / Output
- **Input:**  
  - File containing DNS zones or networks in CIDR (one per line, optionally quoted).
- **Output:**  
  - Cleaned intermediate file: `clean_<zones.txt>`  
  - Converted reverse zones (added to cleaned file)  
  - Final result file: `result_<zones.txt>` with zones sorted  
  - Log file: `sort_list_of_domains.log`  
- Temporary files (`reverse_*`, `clean_*`) are deleted at the end.

---

## Notes
- Supported reverse CIDR formats: `/8`, `/16`, `/24`.  
- Zones are sorted **hierarchically** (e.g., `a.example.com` will appear before `z.example.com`).  
- Non-supported CIDR masks are skipped with a warning.  
- Reverse and forward zones are merged into the same sorted output.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
