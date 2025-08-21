# merge_csvs.sh

## Description
This script merges multiple **CSV files** from a given directory into one consolidated, timestamped CSV file.  
It keeps only the header from the first file, merges the rest in sorted order, and provides statistics on line counts.  
If the `ssconvert` tool is available, it also generates an Excel `.xls` version of the merged file.

---

## Usage
```bash
./merge_csvs.sh <directory>
```

Example:
```bash
./merge_csvs.sh ./exports
```

---

## Features
- Processes all `.csv` files in the target directory.  
- Sorts files by name before merging.  
- Header row is preserved from the **first** CSV only.  
- Counts and displays:
  - Data lines per input file  
  - Total expected vs. actual merged line counts  
- Creates output files:
  - `dns_zone_overview_<timestamp>.csv`  
  - `dns_zone_overview_<timestamp>.xls` (if `ssconvert` available)  

---

## Output
- **Merged CSV:**  
  ```
  <directory>/dns_zone_overview_<timestamp>.csv
  ```
- **Merged XLS (optional):**  
  ```
  <directory>/dns_zone_overview_<timestamp>.xls
  ```

Console output includes per-file data line counts and verification of totals.

---

## Requirements
- Bash  
- Core tools: `wc`, `tail`, `sort`, `cat`, `date`  
- Optional: [`ssconvert`](http://www.gnumeric.org/) (from Gnumeric) for XLS export  

---

## Notes
- Assumes all CSV files share the same header format.  
- Files must use a standard line ending (`LF`).  
- The merged file includes all rows sequentially, sorted by filename order.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
