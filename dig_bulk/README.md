# dig_bulk.sh

## Description
This script performs bulk DNS queries against a list of servers for a list of zones.  
It checks for the presence of **SOA, NS, and A records** for each zone on each server, logs the results, and reports whether queries succeeded or failed.

---

## Usage
Provide two input files:  
1. **Server list** – DNS servers to query.  
2. **Zone list** – DNS zones to test.  

Run:
```bash
./dig_bulk.sh servers.txt zones.txt
```

Example `servers.txt`:
```
192.0.2.1
ns1.example.com
```

Example `zones.txt`:
```
example.com
sub.example.org
```

---

## Requirements
- Bash (`/bin/bash`)
- Utilities:
  - `dig`
  - `egrep`
  - `wc`, `cat`, `tee`

---

## Input / Output
- **Input:**  
  - `servers.txt`: list of DNS server IPs/hostnames.  
  - `zones.txt`: list of zones (FQDNs).  
- **Output:**  
  - Console output showing query results.  
  - Log file: `dig_bulk_YYYYMMDD-HHMMSS.log`.

---

## Notes
- Record types checked: **SOA**, **NS**, **A**.  
- Each zone is tested against each server.  
- If none of the record types return results, the query is marked as **failure**.  
- Uses `dig` with short timeout (`+time=2 +tries=2 +noedns`).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
