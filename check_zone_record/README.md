# check_zone_record.sh

## Description
This script synchronizes pending DNS zone changes with `rndc sync -clean`, dumps the fully expanded zone content using `named-checkzone`, and filters the output for a specific record name or regular expression.

This is useful for quickly verifying whether a record exists in a given zone file as seen by BIND tooling.

The script currently defines the binary and zone directory locations internally via these variables:
- `RNDC_PATH`
- `NAMED_CHECKZONE_PATH`
- `ZONE_PATH`

These paths are configurable in the script and can be adapted to match the local installation.

---

## Usage
Run the script with the zone name and the record name or grep pattern:

```bash
./check_zone_record.sh <zone-name> <record-name-or-regex>
```

Example:

```bash
./check_zone_record.sh example.com www
```

Example with a more specific pattern:

```bash
./check_zone_record.sh example.com '^www\s'
```

Before running the script, adjust the path variables in the script if your environment uses different locations.

---

## Requirements
- Bash
- BIND utilities `rndc` and `named-checkzone`
- Access to the directory containing the zone files
- Correct local configuration of these variables in the script:
  - `RNDC_PATH`
  - `NAMED_CHECKZONE_PATH`
  - `ZONE_PATH`

Example values currently used in the script:
- `RNDC_PATH="/usr/local/nessy2/bin"`
- `NAMED_CHECKZONE_PATH="/usr/local/nessy2/bin"`
- `ZONE_PATH="/etc/namedb/zones/master"`

---

## Input / Output
- **Input:**
  - Argument 1: zone name, for example `example.com`
  - Argument 2: record name or grep compatible regular expression
- **Output:**
  - Prints the executed steps:
    - `rndc sync -clean`
    - `named-checkzone -D -o -`
    - `grep -E '<pattern>'`
  - Outputs matching lines from the expanded zone content to standard output

---

## Notes
- The script constructs the zone file path as:
  - `ZONE_PATH/<zone-name>`
- If no arguments are provided, the script exits with:
  - `missing zone name`
  - `missing record name`
- `grep -E` is used, so the second parameter is treated as an extended regular expression, not a literal string.
- Errors from `named-checkzone` are suppressed with `2>/dev/null`.
- The script does not modify the zone content itself, but it does trigger `rndc sync -clean` before validation.
- When moving the script to another system, the embedded path variables should be reviewed first.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
