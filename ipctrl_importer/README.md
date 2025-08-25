# ipctrl_importer.sh

## Description
This script is a wrapper for running **IPControl CLI imports** with CSV files.  
It validates input, runs the import, generates reject/error files, and reports runtime duration.

---

## Usage
```bash
./ipctrl_importer.sh <bash_script> <csv_file>
```

- **bash_script**: Path to the IPControl CLI wrapper script (must be executable).  
- **csv_file**: CSV file to import into IPControl.  

Example:
```bash
./ipctrl_importer.sh ipcontrol_import.sh data.csv
```

---

## Features
- Validates both arguments exist.  
- Uses static credentials (default: `incadmin/incadmin`) — adjust in the script as needed.  
- Runs the import with options:
  - `-f <csv_file>` → import data  
  - `-r <reject_file>` → reject log (same name with `_reject.csv`)  
  - `-e <error_file>` → error log (same name with `_error.csv`)  
- Measures and prints total runtime.  

---

## Output
For input `data.csv`, generates:
- `data_reject.csv` → records rejected by IPControl  
- `data_error.csv` → records with errors  

Console output:
```
process took 0 minutes and 27 seconds
```

---

## Requirements
- Bash  
- IPControl CLI wrapper script (`bash_script`) must be available and executable.  

---

## Notes
- Update `username` and `password` variables in the script with correct IPControl DB credentials.  
- Reject and error files are overwritten each run.  
- Useful for batch imports and migration automation with BlueCat IPControl.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
