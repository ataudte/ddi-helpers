# compare_zone_variants.sh

## Description
Compare **DNS zone file variants** that share the **same filename** but live in **different folders** under a root path.  
The script gathers all matching files (by filename pattern), de‑duplicates identical content, cleans MS‑DNS artifacts, **canonicalizes** them with `named-checkzone`, normalizes records (ignore SOA, ignore TTL, lowercase), and then compares **variants of the same basename**.  
Differences are logged; non‑identical canonical variants are preserved for review.

---

## Usage
```bash
./compare_zone_variants.sh <root_path> prefix=<prefix>
./compare_zone_variants.sh <root_path> suffix=<suffix>
```
- `root_path`: top directory to search recursively
- `prefix=<prefix>`: collect files whose **filenames start** with `<prefix>` (e.g., `db.`)
- `suffix=<suffix>`: collect files whose **filenames end** with `.suffix` (e.g., `.zone`)

Examples
```bash
# Collect files named like db.<zone> found anywhere under /data/zones
./compare_zone_variants.sh /data/zones prefix=db.

# Collect files ending with .example.com
./compare_zone_variants.sh /data/zones suffix=example.com
```

> **Important:** The `prefix` (e.g., `db.`) is **not** how variants are determined. It is only used to **select the file naming syntax** and to derive the zone origin (`db.example.com` → `example.com`).  
> **Variants** are the **same basename** found in **multiple subfolders** (e.g., `/a/db.example.com`, `/b/db.example.com`).

---

## What it actually does

1) **Collect**
- Recursively finds regular files under `<root_path>` matching either:
  - `prefix=<p>` → `-name '<p>*'`
  - `suffix=<s>` → `-name '*.<s>'`
- Skips reverse zones (`in-addr.arpa`, `ip6.arpa`) and `TrustAnchor` files.
- **De‑duplicates by SHA256** before copying into `_working/original/` so identical files aren’t processed twice.

2) **Clean (MS‑DNS artifacts)**
- Removes dynamic timestamps like `[A:XXXXXXX]`.
- Strips `WINSR` records.
- Converts CRLF → LF if needed (DOS line endings).

3) **Canonicalize** (per file)
- If `$ORIGIN` is missing and file starts with `@`/SOA, injects `\$ORIGIN <zone>.` **for canonicalization only**.
- Detects whether file is BIND **text** or **raw** and runs:
  - `named-checkzone -f text -D -o <file>_canon <zone> <file>` or
  - `named-checkzone -f raw  -D -o <file>_canon <zone> <file>`
- **Zone origin derivation:** from the **basename**. For names like `db.<zone>`, the script strips the `db.` prefix (e.g., `db.example.com` → `example.com`).

4) **Group & Compare variants**
- Canonical files are named `<basename>_<N>_canon`.  
- Files with the **same `<basename>`** (same filename pulled from different folders) are considered **variants** of that zone.
- Normalization for diff (`sanitize_zone`):
  - Drop SOA records
  - Ignore TTL in the second field
  - Lowercase & sort
- If all variants are identical → keep one, delete the rest.
- If any variant differs → copy **all** those canonical variants into `_working/variants/` and log the differences.

---

## Output
Generated under `<root_path>/_working/`:
- `original/`  → unique inputs (after de‑dup)
- `canon/`     → canonicalized files (`*_canon`)
- `variants/`  → canonical files for zones where variants differ
- Logs:
  - `compare_zone_variants_<timestamp>.log`
  - `compare_zone_variants_<timestamp>.errors`
  - `compare_zone_variants_<timestamp>.results` (summary of diffs)

Console summary prints the chosen prefix/suffix and paths to all output dirs.

---

## Requirements
- Bash
- BIND utilities: `named-checkzone`
- Core tools: `awk`, `sed`, `grep`, `sort`, `sha256sum`, `dos2unix` (optional)

---

## Notes
- Reverse zones are ignored intentionally.
- Canonicalization uses `named-checkzone -D` so owner names become absolute.
- Normalization intentionally **ignores SOA and TTL** to focus on record content.
- Safe backups (`*.save`) are created before in‑place MS‑DNS cleanups.

---

## License
Covered by the repository’s main [MIT License](../LICENSE).
