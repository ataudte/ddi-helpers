# get_vendor-classes.sh

## Description
This script analyzes a **Microsoft DHCP XML export** and extracts information about **Vendor Classes** and their DHCP options.  

It excludes:
- Classes of type `User`
- Vendor class names starting with `Microsoft`

---

## Usage
```bash
./get_vendor-classes.sh <dhcp_export.xml>
```

Example:
```bash
./get_vendor-classes.sh dhcp_config.xml
```

---

## Features
1. **Vendor Classes**
   - Lists vendor classes (excluding Microsoft and User types).
   - Prints name and description.

2. **Global Option Definitions**
   - For each vendor class, lists global DHCP option definitions:
     - Option name
     - Default value
     - Description

3. **Scope-Specific Option Values**
   - Iterates over all scopes.
   - Shows option values assigned to vendor classes within each scope:
     - Option ID
     - Value
     - Vendor class

4. **Scope Policies**
   - Reports DHCP options set in **scope policies** for vendor classes.

---

## Output
Console output grouped by:
- Vendor Class overview
- Global option definitions
- Scope-specific options
- Scope policy options

Example snippet:
```
Vendor Classes (Excluding 'User' and 'Microsoft*'):
---------------------------------------------------
CiscoAP: Cisco Access Point Class
Polycom: Polycom Phones

Global Option Definitions:
---------------------------------------------------
Vendor Class: CiscoAP
Option: Bootfile - Default: ap.img - Description: Boot image for Cisco AP

Scope-Specific Option Values:
---------------------------------------------------
Scope ID: 10.0.0.0
Option ID: 66, Value: 10.0.0.5, Vendor Class: CiscoAP
```

---

## Requirements
- Bash  
- `xmlstarlet`  

Install on Debian/Ubuntu:
```bash
sudo apt-get install xmlstarlet
```

---

## Notes
- Input must be a valid Microsoft DHCP XML export file.  
- Useful for auditing vendor-specific DHCP option configuration.  
- Only prints to console; redirect output to a file for reporting.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
