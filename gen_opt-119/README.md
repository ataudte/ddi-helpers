# DHCP Option 119 Encoder

## Description
Encodes a list of domain search suffixes into the **RFC 3397 binary format** used for DHCP option 119 (“Domain Search List”).  
Supports standard compact hex output as well as **Microsoft DHCP “Byte Array”** format (for manual entry in the DHCP MMC).

---

## Usage
### Basic examples
Generate a compact hex string:
```bash
python3 opt119_msdhcp.py "example.com corp.example" --compact
```

Generate Microsoft DHCP Byte Array format:
```bash
python3 opt119_msdhcp.py "corp.example eng.corp.example" --msdhcp
```

---

## Requirements
- **Python 3.8+**
- No external libraries required (pure standard library)

---

## Input / Output
- **Input:**  
  - Quoted list of domains (e.g. `"example.com corp.example"`)

- **Output:**  
  - **Default:** Compact or spaced hexadecimal string of the encoded option data  
  - **With `--msdhcp`:**  
    - One byte per line, formatted as `0xNN`  
    - Comma-separated byte list, ready to paste into Microsoft DHCP’s *Byte Array* field

---

## Notes
- Implements **RFC 3397 / RFC 1035** label compression within the option value.  
- Microsoft DHCP does not natively support RFC 3397 encoding, but this output can be used to manually populate a *Byte Array* option definition.  
- Typical DHCP configuration:
  - **Option Code:** 119  
  - **Data Type:** Byte Array  
- Reference: [RFC 3397 – Dynamic Host Configuration Protocol (DHCP) Domain Search Option](https://datatracker.ietf.org/doc/html/rfc3397)

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
