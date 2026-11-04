# ddns_update.sh & ddns_clean-up.sh

## Description
Two shell scripts to **create/update** and **remove** DNS records by feeding `nsupdate` with commands derived from a simple CSV-like input file.

- **ddns_update.sh**  
  - For each line `ip,alias,host`, it:
    - adds an **A** record for `host` → `ip`
    - adds a **PTR** record for `ip` → `host`
  - After a short wait, it processes the same input again to:
    - delete any **A** record that might exist for `alias`
    - add a **CNAME** record `alias` → `host`

- **ddns_clean-up.sh**  
  - Pulls the zone from a DNS server (**AXFR**) and canonicalizes it.
  - Uses the IPs from the input file to find matching hosts in the zone.
  - Builds and runs `nsupdate` deletions for those hosts.

Both scripts capture daemon logs, keep per-run artifacts, and produce a tarball for handover/audit.

---

## Usage

### Input format
A plain text file where each line is:
```
ip,alias,host
```
Example:
```
192.0.2.50,web-alias.example.com,web01.example.com
192.0.2.51,db-alias.example.com,db01.example.com
```

### Run the update
```bash
./ddns_update.sh input.txt
```

What happens:
- Adds/updates A + PTR for each `host`/`ip`.
- Waits ~5 minutes, then creates CNAMEs `alias` → `host` (and removes any A on `alias` first).

### Run the clean-up
```bash
./ddns_clean-up.sh input.txt
```

What happens:
- AXFRs the zone from the configured DNS server.
- Canonicalizes the zone.
- Deletes host records matching the IPs from `input.txt`.

---

## Configuration (defaults in the scripts)
- **Target DNS server** (`dnsServer`):
  - `ddns_update.sh`: `10.20.30.40`
  - `ddns_clean-up.sh`: `10.20.30.40`
- **Zone for clean-up** (`dnsZone` in `ddns_clean-up.sh`): `zone.de`

Change these variables at the top of each script to match your environment.

---

## Requirements
- POSIX shell (`/bin/sh`)
- Tools:
  - `nsupdate` (for dynamic updates)
  - `dig` (zone transfer for clean-up)
  - `named-checkzone` (canonicalization)
  - `tar`, `awk`, `sed`, `egrep`, `tail`
- DNS permissions:
  - Updates allowed for the target zone (TSIG or policy as applicable).
  - AXFR permitted from the DNS server used by `ddns_clean-up.sh`.

---

## Input / Output
- **Input:** `input.txt` with `ip,alias,host` triplets.
- **Output (per run):**
  - A working directory under the script path:
    - `nNC_update_<YYYYmmdd-HHMMSS>` (update)  
    - `nNC_clean-up_<YYYYmmdd-HHMMSS>` (clean-up)
  - Generated `nsupdate-*.txt` request files
  - Captured `daemon.log` excerpt
  - A tarball in `/tmp/`:
    - `/tmp/nNC_update_<timestamp>.tar.gz`
    - `/tmp/nNC_clean-up_<timestamp>.tar.gz`
  - A log file alongside the scripts:
    - `ddns_update.log`
    - `ddns_clean-up.log`

---

## Notes
- The 5-minute pause in **ddns_update.sh** is intentional to allow DNS propagation before adding CNAMEs.
- **ddns_clean-up.sh** canonicalizes the zone before matching to avoid false positives.
- If updates require TSIG, adapt the `nsupdate` sections to include `key`/`realm` lines as needed.
- Both scripts remove older run artifacts/archives to keep the environment clean.

---

## License
These scripts are covered under the repository’s main [MIT License](../LICENSE).
