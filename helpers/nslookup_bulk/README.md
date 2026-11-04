# nslookup_bulk.bat

## Description
Batch script for Windows to perform **bulk DNS lookups**.  
It iterates through a list of FQDNs, queries a specified DNS server for a given record type using `nslookup`, and saves results to files.

---

## Usage
Prepare a text file (`list-of-fqdns.txt`) with one FQDN per line:
```
example.com
sub.example.org
host.test.net
```

Run the batch script:
```cmd
nslookup_bulk.bat
```

---

## Configuration
The following variables can be modified inside the script:

```bat
set OUTPUTFILE=results.txt       :: File to store query results
set ERRORFILE=error.txt          :: File to store errors
set DNSSERVER=10.20.30.40        :: DNS server to query
set RECORDTYPE=NS                :: Record type (e.g., A, AAAA, NS, MX)
set lookup=list-of-fqdns.txt     :: Input file with FQDNs
```

---

## Input / Output
- **Input:**  
  - `list-of-fqdns.txt` (list of FQDNs to query).  
- **Output:**  
  - `results.txt`: successful query results.  
  - `error.txt`: errors encountered during queries.  

---

## Notes
- Default record type is **NS**, but can be changed to **A**, **AAAA**, **MX**, etc.  
- Make sure the DNS server (`DNSSERVER`) is reachable from the system running the script.  
- This script is intended for quick bulk checks in Windows environments.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
