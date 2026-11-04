# count_active_leases.sh

## Description
This script parses the ISC DHCP **leases file** and counts:
- **Active leases (unique IPs)**  
- **Active clients (unique MAC addresses)**  

It provides a quick snapshot of current DHCP usage.

---

## Usage
Run directly on the DHCP server:

```bash
./count_active_leases.sh
```

---

## Requirements
- Bash (`/bin/bash`)  
- Tools:  
  - `awk`  
  - `sort`, `wc`  

---

## Input / Output
- **Input:**  
  - Default leases file:  
    ```
    /replicated/var/state/dhcp/dhcpd.leases
    ```
  - (Update the script variable `LEASES_FILE` if your leases file is in a different location).  

- **Output:**  
  Console summary, for example:
  ```
  Active Leases (Unique IPs): 142
  Active Clients (Unique MACs): 138
  ```

---

## Notes
- Only **active** leases (`binding state active;`) are counted.  
- IP addresses are counted uniquely, even if reassigned multiple times.  
- MAC addresses are counted uniquely, representing distinct clients.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
