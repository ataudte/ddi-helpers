# zones_from_dotted_hosts.sh & zone_to_subzones.sh

## Description
These two scripts work together to analyze and split DNS zone files into **subzones**.

- **zones_from_dotted_hosts.sh**  
  Extracts and cleans hostnames from a normalized DNS zone file.  
  Produces lists of zone-level records and **subzones**.

- **zone_to_subzones.sh**  
  Takes the parent zone file and the list of subzones, and generates **dedicated zone files** for each subzone with SOA/NS records.

---

## Usage

### Step 1: Extract subzones
```bash
./zones_from_dotted_hosts.sh <normalized_zone_file>
```
Example:
```bash
./zones_from_dotted_hosts.sh db.example.com_canonised
```

Outputs:
- `result_file.txt` → zone-level hostnames  
- `subzone_file.txt` → list of detected subzones  

### Step 2: Generate subzone zone files
```bash
./zone_to_subzones.sh <normalized_zone_file> <subzones_file>
```
Example:
```bash
./zone_to_subzones.sh db.example.com_canonised subzone_file.txt
```

Outputs:
- Directory `named_<zone>/` containing one file per subzone.  
- Each subzone file includes:
  - Auto-generated SOA record (with serial = current date)  
  - NS record  
  - AAAA record for `dns.<subzone>` (placeholder IPv6)  
  - All records belonging to that subzone from the parent zone file  

---

## Features

### zones_from_dotted_hosts.sh
- Extracts the **zone name** from the SOA record.  
- Identifies fully qualified hostnames ending with the zone name.  
- Cleans, deduplicates, and splits results into:
  - `result_file.txt` → zone-level hosts  
  - `subzone_file.txt` → subzones  

### zone_to_subzones.sh
- Reads the parent **zone file** and **subzones list**.  
- For each subzone:
  - Creates a new zone file with SOA, NS, and a placeholder AAAA record.  
  - Copies all subzone-specific records from the parent file.  
- Ensures child subzone records are removed from parent subzones.

---

## Output

- Intermediate files from **zones_from_dotted_hosts.sh**:
  - `temp_01_export.txt`, `temp_02_no-zone.txt`, etc.  
- Final files:
  - `result_file.txt` → cleaned hostnames in parent zone  
  - `subzone_file.txt` → list of subzones  
  - `named_<zone>/` → directory of generated subzone files  

---

## Requirements
- Bash  
- Tools: `awk`, `grep`, `sort`, `uniq`  
- Normalized zone file (e.g., after `named-checkzone -D`)  

---

## Notes
- The placeholder AAAA record in subzone files (`2001:db8::53`) should be updated to match your environment.  
- Designed for breaking down large zones into manageable subzones.  
- Existing output files/directories may be overwritten.  

---

## License
These scripts are covered under the repository’s main [MIT License](../LICENSE).
