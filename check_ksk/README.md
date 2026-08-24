# check_ksk.sh

## Description
Checks whether a recursive DNS resolver signals a given DNSSEC trust anchor.

The script validates the supplied resolver IP address and key tag, checks basic DNS resolution, converts the decimal key tag to its hexadecimal representation, and performs a trust anchor signaling check using [RFC 8145](https://datatracker.ietf.org/doc/rfc8145/).

---

## Usage
Run the script with the resolver IPv4 or IPv6 address as the first parameter and the DNSSEC key tag as the second parameter:

```bash
./check_ksk.sh <resolver-ip> <key-tag>
```

Examples:

```bash
./check_ksk.sh 192.0.2.53 12345
./check_ksk.sh 2001:db8::53 12345
```

---

## Requirements
- Bash
- `dig`
- Python 3
  - Standard library `ipaddress` module

---

## Input / Output
- **Input:**
  - `$1`: IPv4 or IPv6 address of the recursive DNS resolver
  - `$2`: DNSSEC key tag as a decimal integer between 0 and 65535
- **Output:**
  - Resolver address
  - Decimal key tag
  - Calculated hexadecimal key tag
  - DNS resolution check result
  - RFC 8145 trust anchor signaling check result
- **Exit codes:**
  - `0`: Trust anchor reported
  - `1`: DNS resolution failed or trust anchor was not confirmed
  - `2`: Missing or invalid input, or a required dependency is unavailable

---

## Notes
- The resolver parameter must be an IPv4 or IPv6 address. Hostnames are not accepted.
- The key tag is supplied in decimal form. The script automatically converts it to the four-digit hexadecimal representation used for the trust anchor signaling query.
- The DNS resolution check queries the root SOA record through the specified resolver.
- The trust anchor signaling check uses the `_ta-<key-tag>.` query name described by RFC 8145.
- RFC 8145 defines signaling by validating resolvers toward authoritative servers. The result should therefore not be treated as a generic remote trust anchor introspection mechanism.
- RFC 8145: https://www.rfc-editor.org/rfc/rfc8145.html

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
