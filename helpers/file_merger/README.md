# file_merger.sh

## Description
This script merges all files with a given suffix/extension from a specified directory into a single consolidated file.  
The output file is named after the directory basename plus the chosen suffix.

Each merged file is separated by two newlines for readability.

---

## Usage
```bash
./file_merger.sh <directory> "<file_suffix>"
```

- **directory**: Path to the directory containing the files.  
- **file_suffix**: File suffix/extension to merge (e.g., `.txt`, `.csv`).  

Examples:
```bash
./file_merger.sh ./logs ".log"
./file_merger.sh ./configs ".conf"
```

---

## Features
- Validates input arguments and directory existence.  
- Counts and prints:
  - Total files in directory.  
  - Files matching the given suffix.  
- Creates an output file named:
  ```
  <basename_of_directory><file_suffix>
  ```
  Example:
  - Directory: `logs/`  
  - Suffix: `.log`  
  - Output: `logs.log`  

- Appends contents of each matching file into the output file.  
- Inserts two newlines between each file's content.  

---

## Output
- A single merged file, e.g.:
  ```
  logs.log
  ```
- Console summary of processed files.

---

## Requirements
- Bash  
- Tools: `find`, `cat`, `printf`, `wc`, `sort`  

---

## Notes
- Existing output file with the same name is removed before merging.  
- Hidden files (dotfiles) are ignored.  
- File order is determined by `sort` on filenames.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
