# extract_ms_zip.sh

## Description
This script extracts Microsoft DNS/DHCP export archives that match the naming pattern:
```
MS-DNS-DHCP_*.zip
```
(case-insensitive).  
Each archive is extracted into its own subfolder under an `exports/` directory, and the script reports whether the extracted content contains a `dbs/` folder (commonly used for DNS zone files).

---

## Usage
```bash
./extract_ms_zip.sh <path_to_folder_with_archives>
```

Example:
```bash
./extract_ms_zip.sh ./backups
```

---

## Features
- Handles multiple ZIP archives in a directory.  
- Creates an `exports/` folder under the given path.  
- Extracts each archive into a dedicated subfolder:
  ```
  exports/MS-DNS-DHCP_<timestamp>/
  ```
- Detects and reports if a `dbs/` directory (zone files) is present.  
- Supports `.zip` and `.ZIP` extensions.  

---

## Output
- Extracted files are placed under:
  ```
  <path>/exports/<archive_basename>/
  ```
- Console output confirms:
  - Extraction path.  
  - Whether a `dbs/` folder with zone files exists.  

---

## Requirements
- Bash  
- `unzip` utility  

---

## Notes
- Archives without the `MS-DNS-DHCP_*.zip` pattern are ignored.  
- Existing folders are reused (files may be overwritten).  
- Designed for use with Microsoft DNS/DHCP server export bundles.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
