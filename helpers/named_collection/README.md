# named_collection.sh

## Description
This script recursively searches for **named.conf** files under a given root directory,  
extracts zone information, and generates an overview of all DNS zones and their associated files.  

It helps audit large collections of BIND configurations.

---

## Usage
```bash
./named_collection.sh <root_directory>
```

Example:
```bash
./named_collection.sh /etc/bind
```

---

## Features
- Finds all `named.conf` files under the root directory.  
- Extracts:
  - Zone name
  - Zone file path
  - Folder path of the `named.conf`  
- Generates multiple reports:
  - **named_collection_overview.txt** → raw unsorted overview  
  - **named_collection_overview_sorted.txt** → sorted by reversed domain (hierarchical order)  
  - **named_collection_overview_unique.txt** → unique zone/file combinations  
  - **named_collection_overview_warnings.txt** → warnings for zones linked to multiple files  
- Prints a summary of line counts for each output.  

---

## Output
- Example `named_collection_overview.txt`:
  ```
  example.com,db.example.com,/etc/bind/zones
  example.org,db.example.org,/etc/bind/zones
  ```

- Example warnings:
  ```
  Warning: Zone example.net has multiple different files.
  ```

---

## Requirements
- Bash  
- Tools:
  - `find`
  - `awk`
  - `sed`
  - `sort`
  - `wc`  

---

## Notes
- Sorting uses reversed domain names to reflect hierarchy (`com.example.`).  
- Useful for migration projects, consistency checks, or documentation of zone distributions.  
- Output files are overwritten each run.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
