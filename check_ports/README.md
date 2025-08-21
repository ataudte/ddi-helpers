# check_ports.sh

## Description
This script checks connectivity for a set of predefined ports across multiple servers provided in an input list.  
It validates TCP/UDP services commonly used in DNS, DHCP, NTP, SNMP, and related applications.  
Results are logged to both the console (with color-coded output) and a timestamped logfile.

---

## Usage
Provide a text file containing server hostnames or IP addresses, one per line:  
```bash
./check-ports.sh server-list.txt
```

Example input file (`server-list.txt`):
```
dns1.example.com
192.0.2.10
ntp.example.org
```

---

## Requirements
- Bash / POSIX shell (`/bin/sh`)  
- Linux utilities:  
  - `sed`, `sort`, `uniq`, `awk`, `wc`, `timeout`, `find`  
- Network access to the listed servers  

---

## Input / Output
- **Input:**  
  - A text file with server FQDNs or IP addresses (one per line).  
- **Output:**  
  - Console output with port check results (OK/NOK, color-coded).  
  - Log file created in the script folder: `check-ports_YYYYMMDD-HHMMSS.log`.  
  - Temporary cleaned server list file (`*_clean.txt`) removed after execution.  

---

## Notes
- Ports checked by default:  
  - 22/tcp  
  - 53/tcp, 53/udp  
  - 67/udp, 69/udp  
  - 123/udp  
  - 161/udp  
  - 547/udp, 647/udp, 847/udp  
  - 10042/tcp, 12345/tcp  
- Timeout for each connection attempt: 5 seconds.  
- Old log files (older than 7 days) are automatically deleted.  
- Requires sufficient permissions and firewall rules to allow outbound checks.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
