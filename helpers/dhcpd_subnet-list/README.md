# dhcpd_subnet-list.sh

## Description
This script extracts all **subnet definitions** from an ISC DHCP configuration file (`dhcpd.conf`) and exports them into a CSV file.  
It includes the subnet address, subnet mask, and CIDR notation.

---

## Usage
```bash
./dhcpd_subnet-list.sh <dhcpd.conf file>
```

Example:
```bash
./dhcpd_subnet-list.sh dhcpd.conf
```

---

## Features
- Parses lines of the form:
  ```
  subnet <address> netmask <mask> { ... }
  ```
- Converts the **netmask** to **CIDR notation** using an internal function.  
- Generates a CSV file named after the input file:
  ```
  <basename>.csv
  ```
  Example:
  - Input: `dhcpd.conf`
  - Output: `dhcpd.csv`

- CSV columns:
  - `Subnet`
  - `Mask`
  - `CIDR`

---

## Output
Example `dhcpd.csv`:
```
Subnet,Mask,CIDR
192.168.1.0,255.255.255.0,24
10.0.0.0,255.255.0.0,16
```

---

## Requirements
- Bash  
- No external dependencies (uses only built-in shell tools).  

---

## Notes
- Only processes valid `subnet ... netmask ...` lines.  
- Invalid subnet masks cause the script to exit with an error.  
- Output file is overwritten if it exists.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
