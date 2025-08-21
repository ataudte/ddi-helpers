# reverse_from_network.sh

## Description
This script converts a list of IPv4 networks in CIDR notation into corresponding **reverse DNS zones** (`in-addr.arpa`).  
It supports `/8`, `/16`, and `/24` networks and generates a list of reverse zones.

---

## Usage
Prepare a file `networks.txt` containing IPv4 networks in CIDR format, one per line:
```
10.0.0.0/8
192.168.0.0/16
203.0.113.0/24
```

Run the script:
```bash
./reverse_from_network.sh
```

---

## Requirements
- Bash (`/bin/bash`)  
- Tools:  
  - `awk`  
  - `wc`  

---

## Input / Output
- **Input:**  
  - `networks.txt`: List of IPv4 networks in CIDR format.  
- **Output:**  
  - `reverse-zones.txt`: List of corresponding reverse DNS zones.  

Example output:
```
10.in-addr.arpa
168.192.in-addr.arpa
113.0.203.in-addr.arpa
```

---

## Notes
- Supported network sizes: `/8`, `/16`, `/24`.  
- Unsupported CIDR masks are skipped with a warning.  
- Script overwrites `reverse-zones.txt` on each run.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
