# dns_health_check.sh

## Description
A comprehensive DNS health check script that validates delegation, authoritative servers, SOA records, DNSSEC, mail-related DNS entries, reachability, and network configuration for a given domain.

The script produces detailed output to both stdout and a timestamped log file.

---

## Usage
```bash
./dns_health_check.sh <domain> [dns-server]
```

- **domain**: Domain name to check (required).  
- **dns-server**: Resolver to query (optional, defaults to `9.9.9.9`).  

Example:
```bash
./dns_health_check.sh example.com
./dns_health_check.sh example.org 8.8.8.8
```

---

## Features
- **Delegation & NS Records**
  - Validates parent vs. child NS consistency.
  - Checks whether NS servers respond properly.

- **SOA Records**
  - Collects SOA from all NS.
  - Compares serial numbers, MNAME, RNAME, and timers (refresh, retry, expire, negative TTL).

- **DNSSEC**
  - Verifies DS records at parent.
  - Checks DNSKEY/DS consistency at child.

- **Mail-related Records**
  - MX records
  - SPF (TXT)
  - DKIM (`default._domainkey`)
  - DMARC (`_dmarc`)

- **NS Configuration**
  - Negative TTL
  - Zone transfer (AXFR) check
  - Dynamic DNS update test

- **Reachability**
  - Ping test to the domain
  - UDP/TCP port 53 connectivity check

- **Network / ASN Diversity**
  - Uses `ipinfo.io` API to determine ASN of NS servers.
  - Warns if all NS are in the same ASN.

---

## Output
- Console messages with status indicators (`ERROR`, `WARN`, `HEAD`)  
- A timestamped log file in the same directory:
  ```
  dns_health_check_<hostname>_<YYYYMMDD-HHMMSS>.log
  ```

---

## Requirements
- `dig`
- `nsupdate`
- `ping`
- `nc` (netcat)
- `curl`
- POSIX shell environment

---

## Notes
- Must have internet access for ASN lookups (`ipinfo.io`).  
- Zone transfer and dynamic DNS checks may generate warnings depending on server policy.  
- Intended for troubleshooting and operational DNS audits.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
