# find_split_horizon_zones.sh

## Description
This script compares two **BIND configuration files** (`named.conf` style) to identify **zones defined in both files**.  
It then extracts and compares zone details, highlighting when the **zone type** (e.g., `master`, `slave`, `stub`, `forward`) matches between the two.

It is useful for auditing *internal* vs *external* DNS views and identifying **split-horizon zones**.

---

## Usage
```bash
./find_split_horizon_zones.sh <named1> <named2>
```

- **named1** → First BIND config (e.g., internal view)  
- **named2** → Second BIND config (e.g., external view)  

Example:
```bash
./find_split_horizon_zones.sh /etc/bind/named-internal.conf /etc/bind/named-external.conf
```

---

## Features
- Extracts all `zone "<name>"` declarations from each config.  
- Identifies **common zones** across both configs.  
- For each common zone:
  - Extracts a short details block from each config.  
  - Compares the `type` statement between the two configs.  
  - Prints a banner when the type matches.  
- Provides separators (`----`) between comparisons for readability.  

---

## Output
- Console output showing:  
  - A summary for each common zone.  
  - Highlight banners when zone **types match** in both configs.  

Example snippet:
```
###
### TYPE FOR example.com MATCHES IN named-internal.conf AND named-external.conf ###
###

----
```

---

## Requirements
- Bash  
- Standard UNIX tools: `grep`, `awk`, `sed`  

---

## Notes
- The script only checks **zone presence and type parity**.  
- It does **not** compare file paths, ACLs, or zone records.  
- Zone details are extracted heuristically with `grep -A`, so `named.conf` files should follow standard syntax (`zone "<name>" { ... };`).  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
