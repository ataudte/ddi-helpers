# check_dhcp-options.sh

## Description
This script validates a **Microsoft DHCP XML export** and checks whether each DHCP scope has all critical DHCP options defined.  
It reports any missing options per scope.

---

## Usage
```bash
./check_dhcp-options.sh <path_to_dhcp_xml_file>
```

Example:
```bash
./check_dhcp-options.sh dhcp_export.xml
```

---

## Critical Options Checked
- **1** → Subnet Mask  
- **3** → Router (Default Gateway)  
- **6** → DNS Servers  
- **15** → DNS Domain Name  
- **51** → Lease Time  

---

## Features
- Extracts all `ScopeId` values from the XML.  
- Iterates through each scope and checks for the required DHCP options.  
- Special handling for **Option 1 (Subnet Mask)**, which may not appear as an `OptionValue`.  
- Reports per-scope status:
  - `has all critical options.`  
  - `is missing critical options: <list>`  

---

## Output
- Console output, for example:
  ```
  10.0.0.0 is missing critical options: 6 15
  192.168.1.0 has all critical options.
  # check complete #
  ```

---

## Requirements
- Bash  
- `xmllint` (from libxml2-utils)  

---

## Notes
- Input must be a valid Microsoft DHCP XML export.  
- Useful for auditing DHCP scopes after migration or export.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
