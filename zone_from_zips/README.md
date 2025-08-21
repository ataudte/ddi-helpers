# zone_from_zips.sh

## Description
This script searches through a directory of ZIP archives, looks for a **specific zone file** inside each archive,  
and extracts the matching files into a `_working/` subdirectory.  

Each extracted file is renamed to include both the original zone file name and the archive it came from.

---

## Usage
```bash
./zone_from_zips.sh <zip_dir> <zone_file_name>
```

- `<zip_dir>` → Path to the directory containing ZIP archives  
- `<zone_file_name>` → Exact filename to extract (e.g. `db.example.com`)  

Example:
```bash
./zone_from_zips.sh ./exports db.example.com
```

---

## Features
- Processes all `.zip` or `.ZIP` files in the given directory (top-level only).  
- Extracts only the specified `<zone_file_name>` from each archive.  
- Saves results in:
  ```
  <zip_dir>/_working/
  ```
- Renames extracted files to:
  ```
  <zone_file_name>_<archive_basename>
  ```
  Example: `db.example.com_backup1.zip` → `db.example.com_backup1`.

---

## Output
- Extracted files:  
  ```
  <zip_dir>/_working/<zone_file_name>_<archive-name>
  ```
- Console log:
  - Reports each archive processed  
  - Indicates whether the zone file was found  

---

## Requirements
- Bash  
- `unzip`  

---

## Notes
- If no `.zip` files are found, the script exits with an error.  
- Only files in the **top level** of `<zip_dir>` are processed (not recursive).  
- Existing `_working/` directory will be reused (files may be overwritten).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
