# gen_named.sh

## Description
This script generates a minimal `named.conf` configuration file for BIND by scanning a directory of DNS zone files.  
For each zone file, it extracts the zone name from the SOA record and creates a corresponding `zone` block.

---

## Usage
```bash
./gen_named.sh <path_to_zone_files>
```

- **path_to_zone_files**: Directory containing DNS zone files.  

Example:
```bash
./gen_named.sh /etc/bind/zones
```

---

## Features
- Validates input directory.  
- Scans all files in the given directory.  
- Extracts the zone name from the first SOA record found.  
- Generates a `named.conf` with minimal zone declarations:
  ```conf
  zone "example.com" { type master; file "/etc/bind/zones/example.com.zone"; };
  ```
- Warns if no SOA record is found in a zone file.  

---

## Output
- A file named `named.conf` is created in the current working directory.  
- Example contents:
  ```conf
  // Generated named.conf
  zone "example.com" { type master; file "/etc/bind/zones/example.com"; };
  zone "example.org" { type master; file "/etc/bind/zones/example.org"; };
  ```

---

## Requirements
- Bash  
- Standard UNIX tools: `grep`, `awk`  

---

## Notes
- The script assumes each zone file contains a valid SOA record.  
- If no SOA record is found, the file is skipped with a warning.  
- Useful for quickly bootstrapping a `named.conf` from existing zone files.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
