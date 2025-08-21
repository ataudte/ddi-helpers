# ptr_clean-up.sh

## Description
This script validates and cleans up **reverse DNS (PTR) zones** in a BIND-style DNS setup.  
It ensures that configuration and zone files are consistent, removes Microsoft DNS timestamps, canonicalizes the zones, and logs all actions.

---

## Usage
```bash
./ptr_clean-up.sh <named-directory> <named.conf>
```

- `<named-directory>`: Path to directory containing config & zone files.  
- `<named.conf>`: Main DNS configuration file.  

Example:
```bash
./ptr_clean-up.sh /etc/named named.conf
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Tools:  
  - `named-checkzone` (bind-utils)  
  - `awk`, `egrep`, `grep`, `sed`  

---

## Input / Output
- **Input:**  
  - A `named.conf` file with reverse DNS zone definitions:  
    ```
    zone "<zone-name>" { type master; file "<file-name>"; };
    ```
    `<zone-name>` must equal `<file-name>`.  
  - Corresponding PTR zone files.  

- **Output:**  
  - Canonicalized zone files: `<zonefile>_<suffix>`  
  - Cleaned files (with Microsoft DNS timestamps removed).  
  - Log file: `ptr_clean-up_<timestamp>.log`  

---

## Notes
- Cleans Microsoft DNS `[AGE:xxxxxxx]` timestamps if present.  
- Verifies directory and configuration file exist before processing.  
- Intended for auditing and migration of PTR zones.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
