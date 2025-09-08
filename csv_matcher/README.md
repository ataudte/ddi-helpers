# csv_matcher.sh

## Description
Filter rows from a data CSV into **match** and **miss** files based on wildcard patterns stored in a values CSV.  
Supports per-file delimiters, case-insensitive matching by default, and `*` wildcards for prefix, suffix, and substring matches.

---

## Usage
```bash
csv_matcher.sh [-s] <data_csv> <data_delimiter> <data_col_idx> <values_csv> <value_delimiter> <values_col_idx>
```

- `-s` Case-sensitive matching (default is case-insensitive)
- `data_delimiter` and `value_delimiter`: e.g. `,` `;` `|` or tab as `$'\t'`
- Column indexes are **1-based**

### Examples
```bash
# Comma data, comma values, match against column 1 and 2 respectively
./csv_matcher.sh data.csv ',' 1 values.csv ',' 2

# Tab-delimited data, pipe-delimited values, case-sensitive
./csv_matcher.sh -s data.tsv $'\t' 1 patterns.psv '|' 2
```

---

## Requirements
- macOS or Linux with:
  - bash, awk, grep, head
  - Python 3 (used only for printing readable delimiter diagnostics)
- No external Python modules required

---

## Input / Output
- **Input**
  - `data_csv`: file with rows to classify
  - `data_delimiter`: delimiter used in `data_csv`
  - `data_col_idx`: column in `data_csv` to compare
  - `values_csv`: file whose selected column holds wildcard patterns (`*` anywhere)
  - `value_delimiter`: delimiter used in `values_csv`
  - `values_col_idx`: column in `values_csv` with patterns

- **Output**
  - Two files written next to `data_csv`:
    - `<datafile>_<valuefile>_match.csv`
    - `<datafile>_<valuefile>_miss.csv`

---

## Notes
- Matching
  - Case-insensitive by default, toggle with `-s`
  - `*` wildcard is supported (e.g. `bgp*`, `*abc`, `*def*`)
  - Regex is anchored to the whole field internally
- Delimiters
  - Each CSV can have its **own** delimiter
  - The script checks the **first line** of each file for the provided delimiter and exits with a warning if not found
- Columns
  - Indexes are 1-based
  - If the specified column is missing in a row, that row is written to `miss`
- CSV parsing
  - Simple delimiter split; quoted CSV fields are not handled
  - Empty pattern lines are ignored
- Performance
  - Patterns are precompiled and each data row is streamed through awk

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
