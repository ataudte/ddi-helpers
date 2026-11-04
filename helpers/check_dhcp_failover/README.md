# check_dhcp_failover.sh

## Description
This script checks the **DHCP failover state** on a BlueCat DNS/DHCP Server (BDDS).  
It extracts credentials and association details from the DHCP configuration, connects with `omshell`, and reports both local and partner failover states.

---

## Usage
Run directly on a BDDS with DHCP configured:

```bash
./check_dhcp_failover.sh
```

---

## Requirements
- Bash (`/bin/bash`)  
- Tools:  
  - `awk`  
  - `omshell` (part of ISC DHCP utilities)  

---

## Input / Output
- **Input:**  
  - `/replicated/etc/dhcpd.conf` (must contain `failover peer` and `adoniskey`).  

- **Output:**  
  - Log file: `check_dhcp_failover.log`  
  - Console output of states, for example:  
    ```
    local-state:   normal
    partner-state: normal
    ```

---

## Notes
- The script maps numeric failover codes to human-readable states:  
  - `01`: startup  
  - `02`: normal  
  - `03`: communications interrupted  
  - `04`: partner down  
  - `05`: potential conflict  
  - `06`: recover  
  - `07`: paused  
  - `08`: shutdown  
  - `09`: recover done  
  - `10`: resolution interrupted  
  - `11`: conflict done  
  - `254`: recover wait  

- Temporary command file (`*.cmd`) is deleted after execution.  
- Errors are logged and displayed with clear prefixes (`# ERROR #`).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
