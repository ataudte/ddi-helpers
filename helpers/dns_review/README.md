# dns_review.sh

## Description
This script reviews and validates a BIND-style DNS configuration.  
It takes a `named.conf` and associated zone files, flattens the configuration, checks syntax and zones, removes Microsoft DNS timestamps, and canonicalizes zone files.  
The goal is to provide a clear overview of configuration health and identify issues.

---

## Usage
```bash
./dns_review.sh <named-directory> <named.conf>
```

- `<named-directory>`: Path to directory containing configuration & zone files.  
- `<named.conf>`: Name of the main configuration file.  

Example:
```bash
./dns_review.sh /etc/named named.conf
```

---

## Requirements
- POSIX shell (`/bin/sh`)  
- Tools:  
  - `named-checkconf` (bind-utils)  
  - `named-checkzone` (bind-utils)  
  - `awk`, `egrep`, `grep`, `sed`  

---

## Input / Output
- **Input:**  
  - `named.conf` and referenced zone files.  
- **Output:**  
  - Flattened config file: `<named.conf>_flat.conf`.  
  - Zone lists per type (master, slave, forward).  
  - Canonicalized zone files (timestamped).  
  - Log file: `dns_review_<timestamp>.log`.  

---

## Notes
- Cleans Microsoft DNS `[AGE:xxxxxxx]` timestamps from zone files.  
- Validates presence of required tools before execution.  
- Highlights missing or invalid config entries in the log.  
- Intended for DNS administrators performing audits/migrations.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
