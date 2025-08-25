# replace_column.sh

## Description
This script replaces all values in a specified **column of a CSV file** with a new value.  
The modified data is saved into a new CSV file with the replacement value embedded in the filename.

---

## Usage
```bash
./replace_column.sh <input_file> <column_number> <replacement_value>
```

- **input_file** → Path to the CSV file  
- **column_number** → Target column number (1-based)  
- **replacement_value** → Value to insert into the specified column  

Example:
```bash
./replace_column.sh data.csv 3 NEWVALUE
```

---

## Features
- Validates argument count and input file existence.  
- Automatically generates output filename:
  ```
  <basename>_<replacement_value>.csv
  ```
  Example:
  - Input: `data.csv`
  - Replacement value: `NEWVALUE`
  - Output: `data_NEWVALUE.csv`

- Preserves CSV formatting.  
- Uses `awk` for efficient column replacement.  

---

## Output
- A new CSV file with the specified column replaced.  
- Console message summarizing the action, e.g.:
  ```
  Column 3 in data.csv replaced with 'NEWVALUE' and saved to data_NEWVALUE.csv.
  ```

---

## Requirements
- Bash  
- `awk`  

---

## Notes
- Column numbering starts at **1**.  
- Default field separator is a comma (`,`). Adapt the script if your CSV uses a different delimiter.  
- Input file is left untouched; output is written to a new file.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
