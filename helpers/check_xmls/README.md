# check_xmls.sh

## Description
This script scans a given directory for `.zip` files and verifies whether each contains expected DHCP and DNS XML configuration files (`*_dhcp.xml`, `*_dns-config.xml`).
It logs missing files and errors into separate CSV reports.

---

## Usage
```bash
./check_xmls.sh <directory_path>
```

- **directory_path**: Directory containing ZIP files to check.  

Example:
```bash
./check_xmls.sh ./exports
```

---

## Features
- Scans only `.zip` files in the given directory.  
- Verifies the presence of:
  - `*_dhcp.xml`
  - `*_dns-config.xml`
- Produces CSV reports:
  - `no-dhcp-xml.csv` → ZIP files missing DHCP XML  
  - `no-dns-xml.csv` → ZIP files missing DNS XML  
  - `bad-zips.csv` → ZIP files that are unreadable/corrupted  
- Provides console progress and summary.  

---

## Output
- **CSV Reports** in the current working directory:
  - `no-dhcp-xml.csv`
  - `no-dns-xml.csv`
  - `bad-zips.csv`

- **Console Output:**  
  ```
  Report for ZIP files in './exports'
  ----------------------------------------
  Total ZIP files found: 42

  [1/42] Processing file1.zip ... OK
  [2/42] Processing file2.zip ... missing *_dhcp.xml
  ...
  ```

---

## Requirements
- Bash  
- Tools:
  - `find`
  - `unzip`  

---

## Notes
- The script only inspects top-level `.zip` files in the given directory.  
- Output CSV files are overwritten each time the script runs.  
- Useful for auditing DHCP/DNS configuration exports packaged as ZIP files.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
