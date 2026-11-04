# dns_zip2csv.sh

## Description
This script processes **ZIP archives** containing DNS export files and generates a **merged CSV summary** of all discovered zones.

It:
1. Extracts `*_dns-config.xml` files from ZIP archives in the given directory.  
2. Runs an inline Python parser to read the XML files.  
3. Collects details such as:
   - Server name
   - Global forwarders
   - Zone type
   - Replication settings
4. Produces a consolidated CSV file.

---

## Usage
```bash
./dns_zip2csv.sh <directory-with-zip-files>
```

Example:
```bash
./dns_zip2csv.sh ./exports
```

---

## Features
- Works with multiple `.zip` files in a directory.  
- Automatically extracts only `*_dns-config.xml` files.  
- Merges all results into a single CSV file for easier analysis.  
- Handles case-insensitive `.zip` extensions.  

---

## Output
- Extracted XML files are placed in:
  ```
  <directory>/dns_xml_files/
  ```
- Merged CSV file is saved as:
  ```
  <directory>/dns_zones_merged.csv
  ```

---

## Requirements
- Bash  
- Tools:
  - `unzip`  
  - `python3` (for inline XML parsing)  

---

## Notes
- ZIP files without `*_dns-config.xml` will be skipped.  
- If no ZIP files are found, the script exits gracefully.  
- Designed for auditing/exporting Microsoft DNS configurations packaged as ZIP + XML.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
