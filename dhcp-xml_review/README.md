# dhcp-xml_review.py

## Description
This Python script parses a **Microsoft DHCP XML export** and generates multiple structured CSV files for analysis.  
It extracts server-wide options, scopes, reservations, and class assignments (VendorClass/UserClass).  

---

## Usage
```bash
python dhcp-xml_review.py <dhcp_export.xml> [--out <output_dir>]
```

- **dhcp_export.xml** → Path to Microsoft DHCP XML export  
- **--out <output_dir>** → Directory for CSV output (default: `.`)  

Example:
```bash
python dhcp-xml_review.py dhcp_config.xml --out ./csv_output
```

---

## Features
- Cleans XML namespaces.  
- Extracts:
  1. **Options**
     - Global/server options
     - Subnet scope options
     - Reservation-level options
  2. **Scopes**
     - ScopeId, Name, SubnetMask, StartRange, EndRange, LeaseDuration, State, Description
     - Option values per scope
  3. **Reservations**
     - IP address, ClientId, Name, Type, Description
     - Option values per reservation
  4. **Class Assignments**
     - VendorClass/UserClass usage across scopes and reservations  

- Outputs separate CSV files, prefixed with the input XML filename.  

---

## Output
For input `dhcp_config.xml`, generates:

- `dhcp_config-options.csv`  
- `dhcp_config-scopes.csv`  
- `dhcp_config-reservations.csv`  
- `dhcp_config-classes.csv` (if class usage is found)  

---

## Requirements
- Python 3  
- Libraries:
  - `pandas`  

Install dependencies:
```bash
pip install pandas
```

---

## Notes
- Input must be a valid Microsoft DHCP XML export.  
- Option IDs are preserved as numeric column names in the CSVs.  
- Columns are sorted with metadata first, option IDs after.  
- Useful for migration audits, DHCP server reviews, or documentation.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
