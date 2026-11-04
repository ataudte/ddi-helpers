# compare_pattern.sh

## Description
This script compares two files by extracting all lines that contain a given search pattern.  
It normalizes the matches and produces multiple output files, including raw matches, unique matches, common lines, and diffs.

---

## Usage
```bash
./compare_pattern.sh "pattern" file1 file2
```

- **pattern**: Search string or regex pattern (quoted).  
- **file1**: First input file.  
- **file2**: Second input file.  

Example:
```bash
./compare_pattern.sh "example.com" zones_a.txt zones_b.txt
```

---

## Features
- Validates input arguments and file existence.  
- Extracts lines matching the given pattern from each file.  
- Creates sanitized filenames for output.  
- Produces the following result files:
  - `<pattern>_matches_<file1>.txt`  
  - `<pattern>_matches_<file2>.txt`  
  - `<pattern>_unique_<file1>.txt`  
  - `<pattern>_unique_<file2>.txt`  
  - `<pattern>_only_in_<file1>.txt`  
  - `<pattern>_only_in_<file2>.txt`  
  - `<pattern>_common.txt`  
  - `<pattern>_diff_unified.txt` (standard `diff -u`)  
  - `<pattern>_diff_side.txt` (side-by-side `diff -y`)  

---

## Output
- **Console**: Progress messages and usage errors.  
- **Files**: Written to current working directory with sanitized names based on the pattern and input files.  

---

## Requirements
- Bash  
- Tools:
  - `grep`
  - `sed`
  - `sort`
  - `comm`
  - `diff`  

---

## Notes
- Pattern should be quoted to avoid shell expansion.  
- Useful for DNS zone audits, configuration comparisons, or log file analysis.  
- Output files are overwritten if they already exist.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
