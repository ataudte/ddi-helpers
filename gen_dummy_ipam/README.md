# gen_dummy_ipam.sh

## Description
This script generates a **CSV file** containing all subnets derived from a given **CIDR network** and a target **subnet mask size**.  

It is useful for creating dummy IPAM data sets for testing or lab environments.

---

## Usage
```bash
./gen_dummy_ipam.sh <network/CIDR> <subnet_mask_size>
```

- **network/CIDR**: Base network with CIDR (e.g., `192.168.0.0/16`)  
- **subnet_mask_size**: Desired subnet mask size (e.g., `24`)  

Example:
```bash
./gen_dummy_ipam.sh 10.0.0.0/16 24
```

---

## Features
- Converts between dotted IPs and decimal for calculations.  
- Computes number of subnets that fit inside the given CIDR.  
- Writes all subnets into a CSV file with format:
  ```
  Subnet
  10.0.0.0/24
  10.0.1.0/24
  10.0.2.0/24
  ...
  ```

- Output filename is derived from the base network, e.g.:
  ```
  10-0-0-0_16.csv
  ```

---

## Output
- CSV file containing all subnets of the given size within the CIDR block.  
- First line is the header `Subnet`.  
- Each subsequent line is a subnet in CIDR notation.  

---

## Requirements
- Bash  
- Core tools: `sed`, `printf`  

---

## Notes
- Only works with IPv4.  
- The `<subnet_mask_size>` must be larger than or equal to the base CIDR size.  
- Designed for generating test datasets, not production IPAM management.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
