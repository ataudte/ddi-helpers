# dublicated_entries.sh

## Description
This script validates DNS zone files for **duplicate entries**:  
- Hosts mapped to multiple IP addresses.  
- IP addresses mapped to multiple hosts.  

It canonicalizes the zone file, removes Microsoft DNS timestamps, optionally deletes specified RR types, and then runs duplicate validation.  
Results are logged to timestamped files.

---

## Usage
```bash
./dublicated_entries.sh -n <zone-name> -z <zone-file> [-d]
```

Options:
- `-n`: DNS zone name to validate.  
- `-z`: Zone file to validate.  
- `-d`: Enable debug mode (verbose logging).  

Example:
```bash
./dublicated_entries.sh -n example.com -z db.example.com
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Tools:  
  - `named-checkzone` (bind-utils)  
  - `awk`  
  - `sed`, `egrep`  

---

## Input / Output
- **Input:**  
  - Zone file (e.g., `db.example.com`).  
  - Zone name (e.g., `example.com`).  
- **Output:**  
  - Main log file: `dublicated-entries.log`.  
  - Canonicalized zone file: `<timestamp>_prefix_zonefile`.  
  - Validation logs: `<timestamp>_<zone>_host-validation.log` and `<timestamp>_<zone>_ip-validation.log`.  

---

## Notes
- Cleans Microsoft DNS `[AGE:xxxxxxx]` timestamps automatically.  
- Duplicate detection types:  
  - **host** → hostnames with multiple IPs.  
  - **ip** → IPs with multiple hostnames.  
- Results include both the original and duplicate entries.  
- Temporary files are timestamped and preserved for audit.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
