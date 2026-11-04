# qip_named_normalizer.sh

## Description
This script prepares a **QIP-exported BIND/named configuration file** for validation and normalization.  
QIP configurations often include unsupported or environment-specific directives that can break `named-checkconf`.  
The script filters those directives, then generates a fully expanded normalized configuration.

---

## Usage
```bash
./qip_named_normalizer.sh <named.conf>
```

Example:
```bash
./qip_named_normalizer.sh named.conf
```

---

## What it does
1. Takes the input `named.conf`.  
2. Uses `awk` to:
   - Comment out `directory` lines (if not already commented).  
   - Comment out `dnssec-enable` lines.  
   - Comment out **entire `qddns { ... }` blocks**, including sub-blocks.  
3. Writes the filtered file as:
   ```
   named_filtered.conf
   ```
4. Runs:
   ```bash
   named-checkconf -p named_filtered.conf > named_normalized.conf
   ```
   which outputs a **fully expanded, normalized configuration**.  
5. Prints the path to the normalized output.

---

## Output
- `<basename>_filtered.conf` → filtered intermediate file  
- `<basename>_normalized.conf` → final normalized config  

Example:
```
named_filtered.conf
named_normalized.conf
```

---

## Requirements
- Bash  
- `awk`  
- BIND utilities: `named-checkconf`  

---

## Notes
- Only the specified directives/blocks are filtered; everything else is preserved.  
- The normalization step expands `include` statements and outputs a clean, ready-to-validate configuration.  
- Designed to adapt **QIP-generated configs** for compatibility with BIND.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
