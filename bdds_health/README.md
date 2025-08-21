# bdds_health.sh

## Description
Health check script for **BlueCat DNS/DHCP Server (BDDS)**.  
It validates prerequisites, collects system and service status (CPU, memory, filesystem, processes), inspects **DNS (named)** and **DHCP (dhcpd)** services, summarizes DHCP lease states, and records BlueCat software version and applied patches.  
All results are written to a timestamped logfile on the BDDS itself.

---

## Usage
Run locally on a BDDS (root/sudo recommended):  
```bash
./bdds_health.sh
```

No arguments are required.

---

## Requirements
- POSIX shell (`/bin/sh`)
- Utilities present on BDDS:
  - `uptime`, `who`, `mpstat`, `free`, `pgrep`, `named-checkconf`, `lscpu`, `ps`, `top`, `awk`, `sort`, `head`, `tail`, `df`, `grep`, `sed`, `cat`, `hostname`, `date`, `readlink`
- Access to standard BDDS paths:
  - DNS: `/replicated/jail/named/etc/named.conf`
  - DHCP: `/replicated/etc/dhcpd.conf`, `/replicated/var/state/dhcp/dhcpd.leases`
  - Version/Patch info: `/var/patch/release/version.dat`, `/var/patch/patchDb.csv`

---

## Input / Output
- **Input:** None (runs on the local BDDS).
- **Output:**  
  - Log file in the script directory:  
    `bdds_health_<HOSTNAME>_YYYYMMDD-HHMMSS.log`
  - Temporary helper files during execution (e.g., `process_mem.txt`, `process_cpu.txt`, `filesystem.txt`, `patch.txt`, `zones.txt`, `leases.*`) that are **cleaned up** at the end.

---

## What it checks
- **Host & uptime**
  - Hostname, primary IP, uptime and last boot time
- **CPU**
  - Per‑CPU utilization via `mpstat`
- **Processes**
  - Top 10 by memory usage (`ps aux`)
  - Top 10 by CPU (from `top`)
- **Filesystem**
  - `df -h` summary and notable mounts
- **Memory & swap**
  - Totals/used/free from `free -m`
- **BlueCat version & patches**
  - Contents of `version.dat`
  - Patch list from `patchDb.csv`
- **DNS service (named)**
  - Presence of `named.conf`, PID via `pgrep named`
  - Zone file inventory (when present)
- **DHCP service (dhcpd)**
  - Presence of `dhcpd.conf`, PID via `pgrep dhcpd`
  - Lease file parsing and counts by state: `free`, `active`, `backup`

---

## Notes
- Designed for BDDS. For BAM/Proteus health and backups, see your complementary script (e.g., `collect_health_check.sh`).
- The script is **read‑only** with respect to BDDS services; it only reads files and gathers metrics. It creates transient temp files and a logfile.
- Ensure your shell environment includes the listed prerequisites (`mpstat` is provided by `sysstat`).

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
