# search_datarake.sh

## Description
This script searches through `.tgz` archives in a given input directory for a **search string** within `daemon.log` files (including rotated and compressed versions).  
It extracts only the matching log files into a `matched_logs` directory for further analysis, while cleaning up temporary data.

---

## Usage
```bash
./search_datarake.sh <input_directory> <search_string>
```

- **input_directory**: Path containing `.tgz` archives to scan.  
- **search_string**: String or pattern to search for in daemon logs.  

Example:
```bash
./search_datarake.sh ./archives "critical error"
```

---

## Features
- Validates arguments and input directory.  
- Iterates over all `.tgz` files in the input directory.  
- Extracts only `daemon.log*` files (regular, rotated, or compressed).  
- Searches logs for the specified string.  
- Copies matching log files into:
  ```
  ./matched_logs/
  ```
- Sanitizes filenames to avoid conflicts.  
- Cleans up intermediate extraction directories automatically.  

---

## Output
- **matched_logs/** → contains only the daemon log files where matches were found.  
- Console output with progress and error messages.  

---

## Requirements
- Bash  
- Tools:
  - `tar`
  - `grep`
  - `gzip` (for compressed rotated logs)

---

## Notes
- Non-matching archives are ignored.  
- The original `.tgz` archives remain untouched.  
- Useful for filtering large support bundles or log exports for specific error strings.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
