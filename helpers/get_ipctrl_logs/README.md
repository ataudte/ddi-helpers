# get_ipctrl_logs.sh

## Description
This script collects all **IPControl log files** (`*.log*`) from the default installation directory (`/opt/incontrol`) and packages them into a compressed tarball for troubleshooting or support purposes.

---

## Usage
```bash
./get_ipctrl_logs.sh
```

No arguments are required.

---

## Features
- Validates that the IPControl log directory (`/opt/incontrol`) exists.  
- Searches recursively for files matching `*.log*`.  
- Creates a tar archive named:
  ```
  /tmp/logs_<hostname>_<timestamp>.tar
  ```
- Verifies that the tarball is valid.  
- Compresses the tarball with gzip to `.tar.gz`.  
- Prints the resulting file size.  

---

## Output
- A compressed tarball in `/tmp`:
  ```
  logs_<hostname>_<yyyymmdd-hhmmss>.tar.gz
  ```
- Console messages confirming:
  - Log directory existence  
  - Files found  
  - Tarball verification  
  - Compression success and file size  

---

## Requirements
- Bash  
- Tools: `find`, `tar`, `gzip`, `hostname`, `date`, `ls`, `xargs`  

---

## Notes
- If `/opt/incontrol` does not exist or no log files are found, the script exits with an error.  
- Designed for use on BlueCat IPControl servers to quickly bundle logs for analysis or support cases.  
- Existing tarballs in `/tmp` are not removed automatically.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
