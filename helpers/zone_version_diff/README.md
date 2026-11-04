# zone_version_diff.py

## Description
This Python script compares multiple **versions of DNS zone files** in a directory.  
It groups zone files by filename prefix, parses records with **dnspython**, and performs pairwise diffs between versions.  

It outputs per-zone difference reports and global summary CSVs, helping to track changes across zone versions.

---

## Usage
```bash
python zone_version_diff.py <zone_dir>
```

- **zone_dir**: Directory containing normalized zone files (e.g., `db.example.com_1_canon`).  

Example:
```bash
python zone_version_diff.py ./zones
```

---

## Filename Convention
- Files must match the global pattern:
  ```
  *_<version>_canon
  ```
  Examples:
  - `db.example.com_1_canon`
  - `db.example.com_12_canon.txt`

- The **zone name** is inferred from the filename prefix:
  - `db.example.com_1_canon` → zone origin = `example.com`  

---

## Features
- Groups zone files by prefix and version number.  
- Parses records with dnspython:  
  - Owner names → absolute lowercase FQDNs  
  - TTLs → ignored  
  - RR types in `IGNORE_TYPES` (default: SOA) → skipped  
- Skips zones matching `_msdcs.*` if `EXCLUDE_MSDCS = True`.  
- Compares records pairwise between all versions:
  - Writes per-zone `only-in-vX` files with differences.  
  - Creates per-zone pairwise summary CSVs.  
- Generates global reports:
  - `filelist.txt` → all matched files  
  - `zonelist.txt` → unique zone list  
  - `GLOBAL_pairwise_summary.csv` → summary of all diffs  
  - `errors.txt`, `note.txt`  

---

## Output
Output is written into a subdirectory of `<zone_dir>`:
```
dns_diff_report/
├── filelist.txt
├── zonelist.txt
├── GLOBAL_pairwise_summary.csv
├── errors.txt
├── note.txt
├── <zone>/
│   ├── <zone>_pairwise_summary.csv
│   ├── <zone>_v1-v2_only-in-v1.txt
│   ├── <zone>_v1-v2_only-in-v2.txt
│   └── ...
```

---

## Requirements
- Python 3  
- Libraries:
  - `dnspython`  

Install:
```bash
pip install dnspython
```

---

## Notes
- Ensure zone files are normalized (`*_canon`) before running.  
- Only authoritative content is compared; TTLs and ignored RR types are excluded.  
- Useful for regression testing, migration validation, and version auditing of DNS zones.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
