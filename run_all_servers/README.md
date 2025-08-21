# run_all_servers.sh

## Description
This script automates running **SSH commands** or performing **SCP file transfers** across multiple servers from a list.  
It supports batch execution with optional parallelization, input validation, and logging.

---

## Usage
```bash
./run_all_servers.sh -r <ssh|scp> -l <server-list> -p <parameter>
```

Options:
- `-r`: Mode of operation (`ssh` or `scp`).  
- `-l`: File with list of servers (one per line).  
- `-p`:  
  - For `ssh`: the command to run (quote the command).  
  - For `scp`: the file to transfer.  

Example (SSH command on all servers):
```bash
./run_all_servers.sh -r ssh -l servers.txt -p "uname -a"
```

Example (SCP file transfer to all servers):
```bash
./run_all_servers.sh -r scp -l servers.txt -p /path/to/file.txt
```

---

## Requirements
- Bash (`/bin/bash`)  
- Tools:  
  - `ssh`  
  - `scp`  
  - `host` (optional, for DNS checks)  
  - `sort`, `uniq`, `grep`, `wc`  

---

## Input / Output
- **Input:**  
  - Server list file (one hostname/IP per line).  
  - Username and password (prompted interactively).  
- **Output:**  
  - Execution results printed to console.  
  - Log file: `run_all_servers.log` with all actions and errors.  

---

## Notes
- The script removes empty lines and duplicates from the server list.  
- Parallel execution is limited by `max_parallel` (default: 2).  
- If `scp` mode is selected, ensure the source file exists.  
- Uses password-based authentication; SSH keys can be adapted if needed.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
