# run_dnsaudit.sh

## Description
Runs a DNS security scan for a given domain using the **dnsaudit.io** API.

- Saves the full JSON response to a per-domain report file
- Prints a short **Summary** (domain, grade, score, saved path)
- Prints **Issues**, grouped by severity/type (critical, warning, info, secure)

The script prompts interactively for:
- your dnsaudit API key (hidden input)
- the domain name to scan

---

## Usage

Make the script executable (once):

```bash
chmod +x run_dnsaudit.sh
```

Run it:

```bash
./run_dnsaudit.sh
```

You will be prompted for:
- `dnsaudit api key`
- `domain to scan`

### Example session

```text
# dnsaudit api key: ********
# domain to scan: example.com

# Summary
  Domain: example.com
  Grade:  A
  Score:  97
  Saved:  dnsaudit_reports/example.com.json

# Issues (grouped)
  - none
```

### Custom output directory

By default, reports are written to `dnsaudit_reports/`. Override with `OUT_DIR`:

```bash
OUT_DIR=reports ./run_dnsaudit.sh
```

This will write:

- `reports/<domain>.json`

---

## Requirements
- Bash
- `curl`
- `jq`

The script exits early if `curl` or `jq` are missing.

---

## Input / Output
- **Input:**
  - API key (prompted, hidden)
  - Domain (prompted). Anything after a `#` is treated as a comment and removed.
- **Output:**
  - JSON report file: `${OUT_DIR}/${DOMAIN}.json`
  - Console output:
    - Summary section
    - Issues section grouped by type

---

## Notes
- API endpoint used: `https://dnsaudit.io/api/v1/scan?domain=<domain>`
- The script validates that the API response is JSON before writing the report.
- Grouping is based on each issue’s `.type` value (expected: `critical`, `warning`, `info`, `secure`).
- Typical non-zero exit cases:
  - missing dependencies (`curl`, `jq`)
  - empty API key or empty domain
  - API returned non-JSON content (e.g., auth error / HTML error page)

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
