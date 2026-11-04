# bdds_export.sh

## Description
This script collects DNS and DHCP configuration data from a **BlueCat DNS/DHCP Server (BDDS)** and archives it into a compressed `.tar.gz` file.  
It is intended for backup, migration, or troubleshooting scenarios.

---

## Usage
Run directly on a BDDS server with sufficient permissions:

```bash
./bdds_export.sh
```

---

## Requirements
- Bash (`/bin/bash`)  
- Tools:  
  - `rndc` (for journal sync)  
  - `named-checkconf` (bind-utils)  
  - `tar`  
  - `cp`, `mkdir`, `rm`  

---

## Input / Output
- **Input:**  
  - `named.conf` (DNS configuration).  
  - Zone files from `$ZONE_DIR`.  
  - `dhcpd.conf` (DHCP configuration).  

- **Output:**  
  - Normalized DNS config: `named_<hostname>.conf`  
  - Copied DHCP config: `dhcpd_<hostname>.conf`  
  - Zone files in `dbs/`  
  - Consolidated archive:  
    ```
    /tmp/<hostname>_ddi-export_<timestamp>.tar.gz
    ```

---

## Notes
- Journal files are synced before copying (`rndc sync -clean`).  
- If `named.conf`, zone directory, or `dhcpd.conf` are missing, warnings are logged but the script continues.  
- The temporary export directory is cleaned up after archiving.  
- The archive is verified for existence after creation.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
