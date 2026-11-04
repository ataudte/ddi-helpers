# convert_netmask-cidr.sh

## Description
This script converts between **CIDR notation** (e.g., `/24`) and **netmask notation** (e.g., `255.255.255.0`) within a CSV file.  

It is useful for transforming DHCP/DNS/IPAM exports into a consistent format.

---

## Usage
```bash
./convert_netmask-cidr.sh <filename.csv>
```

Example:
```bash
./convert_netmask-cidr.sh subnets.csv
```

---

## Features
- Processes the specified CSV file.  
- Converts:
  - CIDR → Netmask (e.g., `/24` → `255.255.255.0`)  
  - Netmask → CIDR (e.g., `255.255.255.0` → `/24`)  
- Supports configurable column separators (`COLUMN_SEPARATOR`, default: `,`).  

---

## Input / Output
- **Input:**  
  - A CSV file containing subnet information.  
  - Script detects and transforms subnet masks written in CIDR or netmask format.  

- **Output:**  
  - Modified file written to stdout.  
  - Redirect to a new file for saving results:
    ```bash
    ./convert_netmask-cidr.sh subnets.csv > subnets_converted.csv
    ```

---

## Requirements
- Bash  
- `sed`  

---

## Notes
- Default column separator is `,`. Modify `COLUMN_SEPARATOR` in the script for `;` or tab-delimited CSV.  
- Does not modify the input file in place — pipe or redirect output to save results.  
- Only IPv4 netmasks are supported.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
