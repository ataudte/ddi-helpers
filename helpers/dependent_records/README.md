# dependent_records.sh

## Description
This script identifies **dependent DNS records** across multiple zones.  
It performs zone transfers (AXFR) from the primary nameserver of each zone, then compares the transferred data with a given list of records to find dependencies.  
Results are written into separate dependency reports for each zone.

---

## Usage
Provide two input files:  
1. **Zone list** – Zones to query (with trailing dot).  
2. **Record list** – Records to search for (with trailing dot).  

Run:
```bash
./dependent_records.sh zones.txt records.txt
```

Example `zones.txt`:
```
example.com.
sub.example.org.
```

Example `records.txt`:
```
host1.example.com.
app.sub.example.org.
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Linux utilities:  
  - `dig`, `awk`, `grep`, `sed`, `ls`  
- AXFR (zone transfer) must be permitted from the listed primary nameservers.  

---

## Input / Output
- **Input:**  
  - `zones.txt`: list of DNS zones (FQDNs with trailing dot).  
  - `records.txt`: list of records to check for (FQDNs with trailing dot).  
- **Output:**  
  - Zone transfer files: `db.<zone>` (temporary, cleaned up).  
  - Dependency reports per zone: `dependencies_<zone>.txt`.  
  - Log file: `dependent_records_<timestamp>.log`.  

---

## Notes
- The script uses `dig SOA` to identify the primary nameserver for each zone.  
- Zone transfer may fail if the primary does not allow AXFR from the host running the script.  
- Temporary files are automatically deleted after processing.  
- Output files list dependent records and their matches in the zone data.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
