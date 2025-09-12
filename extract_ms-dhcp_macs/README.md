# extract_ms-dhcp_macs.py

## Description
This script extracts MAC-to-IP mappings from a Microsoft DHCP Server XML export.  
It generates a complete list of all MACs and their associated IPs and a filtered list showing only MACs with multiple IPs.

---

## Usage
Run via Python 3:

```bash
python extract_ms-dhcp_macs.py MS-DHCP-01_dhcp.xml
```

This will generate:
- `MS-DHCP-01_dhcp_MACs-all.csv`
- `MS-DHCP-01_dhcp_MACs-multi.csv`

---

## Requirements
- Python 3.7+
- No external modules required (uses built-in `xml`, `csv`, `collections`, etc.)

---

## Input / Output
- **Input:**  
  Microsoft DHCP export XML file with `<Reservation>`, `<ClientId>`, and `<IPAddress>` tags.

- **Output:**  
  - `_MACs-all.csv`: All MACs and their IPs.  
  - `_MACs-multi.csv`: Only MACs with more than one IP.

Format:

```csv
aabbccddeeff,192.168.1.10|192.168.1.11
```

---

## Notes
- MAC addresses are normalized (lowercase, no separators: `aabbccddeeff`)
- CSV files are sorted by MAC address.
- Only Reservation entries with both MAC and IP are included.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
