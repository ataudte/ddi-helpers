# dns_diff_tool.sh

## Description
This script compares two DNS zone files (e.g., before and after a migration).  
It canonicalizes the zone files, removes Microsoft DNS timestamps and ignorable records, then uses `ldns-compare-zones` to generate a clean, auditable diff.  
Logs are written to `dns_diff_tool.log`.

---

## Usage
```bash
./dns_diff_tool.sh -n <zone-name> -1 <pre-zone-file> -2 <post-zone-file> [-d]
```

Options:
- `-n`: Zone name to compare (required).  
- `-1`: Pre-migration zone file.  
- `-2`: Post-migration zone file.  
- `-d`: Display full diff details (default is summary only).  

Example:
```bash
./dns_diff_tool.sh -n example.com -1 example_pre.db -2 example_post.db -d
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Tools:
  - `named-checkzone` (part of **bind-utils**)  
  - `ldns-compare-zones` (part of **ldns-utils**)  
- Standard Unix utilities: `sed`, `egrep`, `date`  

---

## Input / Output
- **Input:**  
  - Two zone files (`pre` and `post`) to compare.  
- **Output:**  
  - Canonicalized zone files: `<timestamp>_pre.can.<filename>`, `<timestamp>_post.can.<filename>`  
  - Log file: `dns_diff_tool.log` with results and any actions taken.  
  - Console output with summary/detailed differences.  

---

## Notes
- Microsoft DNS dynamic timestamps (`[AGE:xxxxxxx]`) are automatically removed before comparison.  
- Default ignored record types: **NS** (to avoid noise in diffs).  
- For a quick overview, run without `-d`. Use `-d` for detailed record-level differences.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
