# check_ksk.sh

## Description
Checks whether a recursive DNS resolver trusts a given root DNSSEC trust anchor using RFC 8509.

The script tests all published Root Canary measurement zones. Each zone is first used as a DNSSEC baseline candidate. Only zones where the secure name resolves normally and the bogus name returns `SERVFAIL` are considered DNSSEC eligible.

RFC 8509 `is-ta` and `not-ta` sentinel checks are then run only against those eligible zones. The final result is based only on determinate `TRUSTED` and `NOT_TRUSTED` outcomes.

The optional `-v` flag enables detailed per-zone and excluded-zone output.

---

## Usage
Run the script with the resolver IPv4 or IPv6 address and the DNSSEC key tag:

```bash
./check_ksk.sh <resolver-ip> <key-tag>
```

Enable verbose output with:

```bash
./check_ksk.sh -v <resolver-ip> <key-tag>
```

Examples:

```bash
./check_ksk.sh 192.0.2.53 38696
./check_ksk.sh -v 2001:db8::53 38696
```

---

## Requirements
- Bash
- `dig`
- `awk`
- Python 3
  - Standard library `ipaddress` module
- Network access to the Root Canary DNSSEC test infrastructure

---

## Input / Output
- **Input:**
  - `-v`: Optional verbose output
  - `$1`: IPv4 or IPv6 address of the recursive DNS resolver
  - `$2`: DNSSEC root key tag as a decimal integer between `0` and `65535`
- **Default Output:**
  - Resolver address
  - Key tag
  - Number of Canary zones tested
  - DNS resolution result
  - Progress bar
  - Candidate filtering statistics
  - RFC 8509 sentinel result distribution
  - Overall trust anchor result
  - Trust Consensus
  - Test Coverage
- **Verbose Output:**
  - Everything in the default output
  - Canary Zone Results
  - Excluded Or Divergent Zones
  - Per-zone response details
- **Exit Codes:**
  - `0`: Trust anchor confirmed
  - `1`: Trust anchor not confirmed
  - `2`: Missing or invalid input, or a required dependency is unavailable
  - `3`: Indeterminate result or no determinate sentinel result

---

## Notes
- The resolver parameter must be an IPv4 or IPv6 address. Hostnames are not accepted.
- The key tag is supplied in decimal form.
- RFC 8509 uses the key tag as a five-digit decimal value in the sentinel query names.
- The script uses all 36 Root Canary zones as candidate test zones.
- Each Canary zone is tested with:
  - `secure.<zone>`
  - `bogus.<zone>`
  - `root-key-sentinel-is-ta-<key-tag>.<zone>`
  - `root-key-sentinel-not-ta-<key-tag>.<zone>`
- A Canary zone is DNSSEC eligible only when:
  - the secure name returns `NOERROR` with an A answer
  - the bogus name returns `SERVFAIL`
- Zones that fail the baseline are excluded from the RFC 8509 trust decision.
- Only `TRUSTED` and `NOT_TRUSTED` results vote on the overall trust anchor state.
- `SENTINEL_NOT_OBSERVED` means the resolver validated the DNSSEC baseline, but both sentinel names returned normal A answers. This indicates that RFC 8509 sentinel processing was not observed for that query path. It does not prove that the resolver software globally lacks RFC 8509 support.
- **Trust Consensus** measures agreement among determinate RFC 8509 tests.
- **Test Coverage** measures how many DNSSEC eligible Canary zones produced a determinate RFC 8509 result.
- A resolver can report 100% Trust Consensus with lower Test Coverage when some eligible query paths do not expose RFC 8509 sentinel behavior.
- The Root Canary zones intentionally use different DNSSEC algorithm and denial-of-existence combinations.
- The Root Canary infrastructure is an external dependency.

RFC 8509: https://www.rfc-editor.org/rfc/rfc8509.html

Root Canary repository: https://github.com/moritzcm/root-canary-custom-msm

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
