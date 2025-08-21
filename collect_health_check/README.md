# collect_health_check.sh

## Description
This script automates the collection of health check data from a **BlueCat deployment**, including both:  
- **BlueCat DNS/DHCP Servers (BDDS)**  
- **BlueCat Address Manager (BAM)**  

It executes health and support utilities (`datarake.sh`, `bdds_health.sh`, `backup.pl`), retrieves generated logs and support bundles from BDDS and BAM, and stores all artifacts in a centralized timestamped folder under `/tmp/YYYY-MM`.

---

## Usage
Provide a text file containing BDDS hostnames or IP addresses, one per line:  
```bash
./collect_health_check.sh server-list.txt
```

Example input file (`server-list.txt`):
```
bdds1.example.com
bdds2.example.com
192.0.2.15
```

The script will:
- Prompt for the **root password** of the BDDS servers (used for SSH and SCP).  
- Collect and centralize support/health check data from BDDS and BAM.  

---

## Requirements
- Bash / POSIX shell (`/bin/sh`)  
- Linux utilities:  
  - `sed`, `sort`, `uniq`, `awk`, `wc`, `timeout`, `scp`, `ssh`, `host`  
- Access to BDDS root account via SSH (port 22 must be reachable)  
- BlueCat-specific scripts on servers:  
  - **On BDDS:**  
    - `/usr/local/bluecat/datarake.sh`  
    - `/root/bdds_health.sh`  
  - **On BAM:**  
    - `/usr/local/bluecat/datarake.sh`  
    - `/usr/local/bcn/backup.pl`  

---

## Input / Output
- **Input:**  
  - A text file with BDDS hostnames or IP addresses.  
  - BDDS root password (entered interactively).  
- **Output:**  
  - Centralized support data in `/tmp/YYYY-MM/` including:  
    - `bcn-support.*` (datarake bundles from BDDS)  
    - `bdds_health_*` reports  
    - `backup_default_*.bak` database backups from BAM  
    - `bcn-support.*bam*.tgz` bam datarake  

---

## Notes
- Cleans input list (removes empty lines, duplicates).  
- Skips servers not resolvable by DNS or not reachable on SSH.  
- Requires interactive password entry for BDDS root.  
- Old temporary files on BDDS are cleaned up after retrieval.  
- Log file: `collect_health_check.log`.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
