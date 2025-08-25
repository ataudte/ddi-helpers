# bam_health.sh

## Description
This script runs a **health check** on a BlueCat Address Manager (BAM) server.  
It validates prerequisites, gathers system information, checks the application/database state,
and logs results into a timestamped log file.

---

## Usage
```bash
./bam_health.sh
```
No arguments are required.

---

## Features

### BAM / Application
- **BAM Version**: prints the BlueCat Address Manager product version/build.
- **Patch Level**: lists the installed patch level(s).

### Database (PostgreSQL)
- **Connectivity check** using `psql` (user/database from script variables).
- **Database size** in human‑readable form and in bytes:
  - Uses `pg_database_size(current_database())`.
  - Compares against a configurable threshold (e.g., `dbwarn`) and reports **normal** / **warning**.
- **Status line** summarizing DB size and state in the log.

### System Overview
- Hostname and primary IP address.
- **Uptime** and **last boot time**.
- **Logged‑in users** (via `who`).

### CPU
- **CPU count** and per‑CPU utilization (via `mpstat`).
- **Top processes by CPU** consumption.

### Memory
- **Total / used / free memory** (from `free -m`).
- **Top processes by memory** consumption.

### Filesystem
- **Disk usage** summary (`df -Pkh`).
- **Warnings / criticals** when usage exceeds thresholds (values are defined in the script).

### Logging & Housekeeping
- Timestamped, host‑specific logfile:
  ```
  bam_health_<server>_<timestamp>.log
  ```
- Consistent, prefixed log messages for sections and errors.
- Cleanup of temporary section files via a `cleaner` helper.

---

## Output
Console output plus a detailed log file, for example:
```
bam_health_myserver_20250101-120000.log
```
Sample entries:
```
# ----- # ## OVERVIEW ##
# ----- #    Server: bam01 (192.168.1.10)
# ----- #    Uptime: 5 days ( boot: 2025-01-01 08:00 )

# ----- # ## BAM ##
# ----- #    Version: 9.x.x (build ...)
# ----- #    Patch:   BAM-PATCH-...

# ----- # ## DATABASE ##
# ----- #    Database Size: 12.3 GB (normal)
```

---

## Requirements
- Bash  
- Tools: `uptime`, `who`, `mpstat`, `free`, `psql`, `df`, `lscpu`, `top`

---

## Notes
- Log files are created in the same directory as the script.
- Thresholds (filesystem and database size) are configurable within the script variables.
- Designed for BAM server troubleshooting and operational monitoring.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
