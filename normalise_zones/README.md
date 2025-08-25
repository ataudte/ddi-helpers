# normalise_zones.sh

## Description
This script validates and **normalizes DNS zone files** listed in a `named.conf`.  
It separates forward and reverse zones, cleans Microsoft DNS artifacts, canonicalizes each zone with `named-checkzone`, and validates the presence of forward records.  

It is designed to prepare exported DNS zones for migration or audit.

---

## Usage
```bash
./normalise_zones.sh <named-directory> <named.conf>
```

- **named-directory** → Path to directory containing `named.conf` and zone files.  
- **named.conf** → BIND configuration file listing the zones (must follow format):
  ```
  zone "<zone-name>" { type master; file "<file-name>"; };
  ```
  Zone name must equal the file name.

Example:
```bash
./normalise_zones.sh /data/bind named.conf
```

---

## Features
1. **Validation**
   - Checks input arguments and prerequisites (`named-checkzone`, `awk`, `egrep`, `sed`).  
   - Confirms forward and reverse zones exist.

2. **Cleanup**
   - Removes Microsoft DNS dynamic timestamps (`[Aging:xxxxxxx]`).  

3. **Canonicalization**
   - Runs:
     ```bash
     named-checkzone -D -o <file>_canonised <zone> <file>
     ```
   - Produces canonicalized zone files (`*_canonised`).  

4. **Forward Zone Records**
   - Extracts all `A` records from forward zones.  
   - Validates presence of at least one forward record.  

5. **Logging & Cleanup**
   - Logs actions and debug messages into a timestamped log file.  
   - Deletes temporary files (`forward_zones.txt`, `reverse_zones.txt`, etc.).  

---

## Output
- Canonicalized zone files:  
  ```
  <zonefile>_canonised
  ```
- Log file:  
  ```
  normalise_zones_<timestamp>.log
  ```

---

## Requirements
- Bash  
- BIND utilities:
  - `named-checkzone`  
- Tools:
  - `awk`, `sed`, `egrep`, `grep`  

---

## Notes
- Reverse zones are listed separately for validation but not further processed.  
- Cleanup deletes most temporary artifacts but retains canonicalized files.  
- Designed for DNS migration preparation and zone auditing.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
