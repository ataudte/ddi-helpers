# jumper.sh

## Description
Interactive SSH helper script that allows you to select a server from a list and connect to it.  
It validates input, checks connectivity, and logs all actions. Useful as a "jumper" or "bastion" tool for quickly connecting to servers from a predefined inventory.

---

## Usage
Provide a text file with server definitions in the format:
```
name,role,address
```

Run:
```bash
./jumper.sh server-list.txt
```

Example `server-list.txt`:
```
dns01,DNS,192.0.2.1
dhcp01,DHCP,192.0.2.2
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Tools:  
  - `ssh`  
  - `timeout`  
  - `tput`  
  - `sed`, `sort`, `uniq`, `awk`  

---

## Input / Output
- **Input:**  
  - A server list file (`name,role,address`).  
- **Output:**  
  - Console menu to pick a server.  
  - SSH connection to selected server.  
  - Log file: `jumper_<timestamp>.log` in script directory.  

---

## Notes
- The script tests connectivity on port 22 before attempting SSH.  
- SSH is executed as `root` with `StrictHostKeyChecking=no` (accepts new host keys automatically).  
- Temporary cleaned list (`*_clean.txt`) is removed after execution.  
- Old log files may be cleaned automatically.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
