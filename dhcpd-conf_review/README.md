# dhcpd-conf_review.py

## Description
Parses an ISC DHCPD configuration file (`dhcpd.conf`) and exports structured CSVs: **Scopes** (subnets / shared-networks), **Reservations** (hosts) and **Options** (global, scope, host). Columns use `number|name` when a DHCP option number is known (e.g., `6|domain_name_servers`).

---

## Usage
```bash
python dhcpd-conf_review.py /etc/dhcp/dhcpd.conf --out ./output
```
Examples:
```bash
python dhcpd-conf_review.py dhcpd.conf
python dhcpd-conf_review.py dhcpd.conf --out ./exports
```

---

## Requirements
- Python 3.9+
- Modules:
  - Built-in: argparse, re, os
  - External: pandas

No vendor-specific dependencies.

---

## Input / Output
- **Input:**
  - A single ISC DHCP configuration file (e.g., `/etc/dhcp/dhcpd.conf`).
  - Comments (`# ...`) are ignored during preprocessing.
  - Multiline directives are merged; option *definitions* like `option option-101 code 101 = string;` are ignored.

- **Output:**
  - Files are written to `--out` (default: current directory). The file prefix is the input filename without extension.
  - Generated files (only if data exists for that type):
    - `<prefix>-options.csv` — one row per context (global, subnet/shared-network, host), with option columns.
    - `<prefix>-scopes.csv` — subnets and shared networks (adds `State=Active` if missing).
    - `<prefix>-reservations.csv` — host reservations (adds `Type=DHCP` if missing).
  - Columns:
    - Metadata: `Type, Scope, Name, ScopeId, SubnetMask, StartRange, EndRange, LeaseDuration, State, Description, IPAddress, ClientId, BlockType`
    - Options: `number|name` (sorted numerically where possible; unmapped options sorted after).

- **Console output:**
  - Prints a single success message upon completion:
    - `Successfully parsed '<conf_file>' and generated CSV files in '<output_dir>'.`

---

## Notes
- Block types handled: `subnet`, `shared-network`, `host`.
- Global options are captured before the first block and stored as a `global`/`Server` row in `*-options.csv`.
- Option mapping uses well-known DHCP options; unmapped/custom options are retained by name.
- Read-only operation — the script does not modify configuration files.
- Reference: ISC DHCP `dhcpd.conf` manual (RFC 2132 for common options).

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
