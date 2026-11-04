# check_zone.sh

## Description
This script performs a **sanity check** on a DNS zone file.  
It can inject a missing `$ORIGIN` directive if needed, runs BIND’s `named-checkzone`, and saves results into a report file.

---

## Usage
```bash
./check_zone.sh <zone_name> <zone_file>
```

- **zone_name**: FQDN of the zone (e.g., `example.com`)  
- **zone_file**: Path to the zone file to validate  

Example:
```bash
./check_zone.sh example.com /etc/bind/zones/db.example.com
```

---

## Features
- Validates script arguments and zone file readability.  
- Injects `$ORIGIN <zone_name>` if missing and SOA is found.  
- Runs `named-checkzone` to perform BIND zone validation.  
- Writes validation results into:
  ```
  <zone_file>.report
  ```
- Provides useful error messages for missing or invalid arguments.  

---

## Output
- Console: Progress and error messages.  
- File: `<zone_file>.report` containing validation results from `named-checkzone`.  

---

## Requirements
- Bash  
- BIND utilities:
  - `named-checkzone`  

---

## Notes
- The script does **not modify the original zone file**; `$ORIGIN` is injected only for the validation run.  
- Useful for CI pipelines, DNS audits, or zone migration checks.  
- Reports are cumulative (appended to existing `.report` files).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
