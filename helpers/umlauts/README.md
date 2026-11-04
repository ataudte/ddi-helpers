# umlauts.sh

## Description
This script searches for files matching a given pattern under a specified directory, repairs double-encoded UTF-8 text, and transliterates German umlauts into ASCII equivalents.

Each processed file is backed up before modification.

---

## Usage
```bash
./umlauts.sh '<pattern>' <path>
```

- **pattern**: Filename pattern (e.g. `*.txt`)  
- **path**: Directory to search  

Examples:
```bash
./umlauts.sh '*.txt' /var/data
./umlauts.sh '*.csv' ./exports
```

---

## Features
- Validates input arguments and path.  
- Recursively finds matching files.  
- Creates a `.save` backup of each file.  
- Repairs double-encoded UTF-8 using `iconv`.  
- Transliterates German umlauts:
  - `ä` → `ae`, `Ä` → `Ae`  
  - `ö` → `oe`, `Ö` → `Oe`  
  - `ü` → `ue`, `Ü` → `Ue`  
  - `ß` → `ss`  

---

## Output
- Modified files (with umlauts transliterated).  
- Backup files named `<filename>.save`.  
- Console output listing each file processed and a final summary.  

---

## Requirements
- Bash  
- Tools:
  - `find`
  - `iconv`
  - `sed`  

---

## Notes
- Always verify the `.save` backups if the transliteration needs to be reversed.  
- Only processes files that match the given pattern.  
- Exits with an error if no files match.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
