# Script Name

## Description
Parses a Microsoft DNS XML export file and extracts a **quick overview** of a single server's configuration.
Extracts Server name, Zone names, Master server IPs, and Global forwarders. Intended as a lightweight helper script for analyzing a **single** XML file.

For more advanced batch processing (multiple ZIPs, zone details, replication scope, etc.), refer to [dns_zip2csv.sh](dns_zip2csv/dns_zip2csv.sh).  

---

## Usage
Run against a Microsoft DNS XML export file:
  
```bash
python parse_ms-dns_xml.py ms-dns-export.xml
```

---

## Requirements
- Python 3.9+
- External modules:  
  - requests  
  - pandas  

---

## Input / Output
- **Input:** One Microsoft DNS XML export file (ms-dns-export.xml).  
- **Output:** A CSV file containing extracted information (zones, masters, forwarders).  

---

## Notes
- Only processes a **single file** at a time.
- Provides a quick overview only; does not extract extended zone attributes.
- For detailed and batch analysis use [dns_zip2csv.sh](dns_zip2csv/dns_zip2csv.sh).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
