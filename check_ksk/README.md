# check_ksk.sh

## Description
Checks whether a recursive DNS resolver trusts a given root DNSSEC trust anchor using RFC 8509.

The script validates the resolver IP address and key tag, confirms basic DNS resolution and DNSSEC validation, and evaluates the RFC 8509 `is-ta` and `not-ta` sentinel responses. It uses the Root Canary test infrastructure under `d2a8n3.rootcanary.net.`.

---

## Usage
Run the script with the resolver IPv4 or IPv6 address as the first parameter and the DNSSEC key tag as the second parameter:

```bash
./check_ksk.sh <resolver-ip> <key-tag>
```

Examples:

```bash
./check_ksk.sh 192.0.2.53 38696
./check_ksk.sh 2001:db8::53 38696
```

---

## Requirements
- Bash
- `dig`
- Python 3
  - Standard library `ipaddress` module
- Network access to the Root Canary DNSSEC test infrastructure:
  - `d2a8n3.rootcanary.net.`

---

## Input / Output
- **Input:**
  - `$1`: IPv4 or IPv6 address of the recursive DNS resolver
  - `$2`: DNSSEC root key tag as a decimal integer between `0` and `65535`
- **Output:**
  - Resolver address
  - Key tag
  - DNS resolution result
  - DNSSEC validation result
  - RFC 8509 `is-ta` result
  - RFC 8509 `not-ta` result
  - Final trust anchor classification
  - Test infrastructure result when the RFC 8509 outcome is otherwise indeterminate
- **Exit codes:**
  - `0`: Trust anchor confirmed
  - `1`: Trust anchor not confirmed
  - `2`: Missing or invalid input, or a required dependency is unavailable
  - `3`: Indeterminate result or RFC 8509 is unsupported

---

## Notes
- The resolver parameter must be an IPv4 or IPv6 address. Hostnames are not accepted.
- The key tag is supplied in decimal form.
- RFC 8509 uses the key tag as a five-digit decimal value in the sentinel query names.
- The script checks the following names under the Root Canary test domain:
  - `bogus.d2a8n3.rootcanary.net.`
  - `root-key-sentinel-is-ta-<key-tag>.d2a8n3.rootcanary.net.`
  - `root-key-sentinel-not-ta-<key-tag>.d2a8n3.rootcanary.net.`
- A validating resolver that supports RFC 8509 should behave as follows:
  - Trusted key: `is-ta` returns an A answer and `not-ta` returns `SERVFAIL`
  - Untrusted key: `is-ta` returns `SERVFAIL` and `not-ta` returns an A answer
  - RFC 8509 unsupported: both sentinel names return A answers while the bogus name returns `SERVFAIL`
  - Non-validating resolver: the bogus and both sentinel names return A answers
- If the responses do not match one of the expected states, the script repeats the sentinel queries with `+cd` to verify that the underlying Root Canary records are available without sentinel processing.
- The Root Canary infrastructure is an external dependency. If it is unavailable or changes behavior, the script returns an indeterminate result rather than reporting a trust anchor failure.
- RFC 8509: https://www.rfc-editor.org/rfc/rfc8509.html
- Root Canary repository: https://github.com/moritzcm/root-canary-custom-msm

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
