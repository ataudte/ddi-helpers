# dns_zone_diag.sh

## Description

`dns_zone_diag.sh` runs a reproducible diagnostic suite for the authoritative DNS hosting of a delegated zone.

The script discovers the zone's authoritative name servers and their published IPv4 and IPv6 addresses. It then compares every reachable server address across:

* UDP and TCP
* IPv4 and IPv6
* Queries with and without EDNS
* EDNS UDP payload sizes of 512, 1232, 1400, and 4096 bytes
* TXT response truncation and automatic TCP fallback
* SOA serial, SOA MNAME, and child NS RRset consistency
* DNS Cookies and NSID, when supported by the installed `dig` version
* Basic DS and DNSKEY retrieval
* Resolution through the local resolver and selected public resolvers

The results help reproduce and analyze server specific, path dependent, EDNS, fragmentation, truncation, and TCP fallback issues.

---

## Usage

Make the script executable:

```bash
chmod +x dns_zone_diag.sh
```

Run the diagnostics for a zone:

```bash
./dns_zone_diag.sh example.com
```

Optionally specify a parent directory for the generated results:

```bash
./dns_zone_diag.sh example.com ./results
```

Display the built in help:

```bash
./dns_zone_diag.sh --help
```

### Optional environment variables

| Variable | Default | Description |
|---|---:|---|
| `DNS_DIAG_TIMEOUT` | `3` | Timeout in seconds for each DNS query |
| `DNS_DIAG_TRIES` | `1` | Number of attempts per DNS query |
| `DNS_DIAG_IPV6` | `auto` | IPv6 mode: `auto`, `force`, or `skip` |
| `DNS_DIAG_SKIP_TRACE` | `0` | Set to `1` to skip the iterative `dig +trace` test |
| `DNS_DIAG_VERBOSE` | `0` | Set to `1` to print complete raw query output while the script runs |
| `DNS_DIAG_PUBLIC_RESOLVERS` | `8.8.8.8 1.1.1.1 9.9.9.9` | Space separated IPv4 addresses of public recursive resolvers to test |
| `DIG_BIN` | Automatically detected | Optional path to a specific `dig` binary |

Examples:

```bash
DNS_DIAG_IPV6=force \
DNS_DIAG_VERBOSE=1 \
./dns_zone_diag.sh example.com
```

```bash
DNS_DIAG_TIMEOUT=5 \
DNS_DIAG_TRIES=2 \
DNS_DIAG_PUBLIC_RESOLVERS="8.8.8.8 1.1.1.1" \
./dns_zone_diag.sh example.com ./results
```

---

## Requirements

* macOS or another Unix like operating system
* Bash 3.2 or later
* `dig` from BIND
* Standard command line tools such as `awk`, `sed`, `grep`, `sort`, `paste`, `tr`, and `date`
* Network access to DNS over UDP and TCP port 53
* IPv6 connectivity for meaningful IPv6 testing

The script has no Python modules, vendor specific dependencies, credentials, or privileged access requirements.

Verify that `dig` is available:

```bash
command -v dig
```

Install a current BIND package with Homebrew when required:

```bash
brew install bind
```

DNS Cookie and NSID tests are skipped automatically when the installed `dig` version does not advertise the corresponding options.

---

## Input / Output

### Input

* **First positional argument:** DNS zone name, for example `example.com`
* **Second positional argument:** Optional output parent directory; defaults to the current working directory

A trailing root label is accepted and removed internally:

```bash
./dns_zone_diag.sh example.com.
```

### Output

The script creates a timestamped result directory using UTC:

```text
dns-zone-diag_<zone>_<YYYYMMDD-HHMMSS>/
```

Example:

```text
dns-zone-diag_example.com_20260807-114512/
```

The directory contains:

* `report.md`: Automated summary of the test results and potential findings
* `summary.tsv`: One machine readable row for every DNS test
* `authoritative-data.tsv`: SOA MNAME, SOA serial, and child NS RRset per authoritative server address
* `nameservers.txt`: Discovered authoritative name servers
* `nameserver-addresses.tsv`: Discovered IPv4 and IPv6 addresses
* `environment.txt`: Script, system, route, and local resolver information
* `delegation-trace.txt`: Iterative delegation trace, unless disabled
* `full.log`: Combined output of all tests
* `tests/`: Separate raw output file for every individual DNS query

If the script is interrupted, the partial result directory is retained for analysis.

---

## Notes

* The script performs read only DNS queries and does not modify zone data or DNS server configuration.
* The generated report is an automated first pass. Review the raw query output before drawing a final conclusion.
* Tests with names ending in `_udp` use `+ignore` so that a truncated response remains visible without an automatic TCP retry.
* Tests ending in `_auto_fallback` allow `dig` to retry over TCP after receiving a response with the TC flag.
* A direct TCP test confirms TCP port 53 only between the client running the script and the tested server address.
* A TCP query to a public recursive resolver does not prove TCP reachability between that resolver and the authoritative servers.
* Anycast routing, source dependent policies, rate limits, DDoS protection, and intermittent failures can produce different results from different measurement points. Repeat the test from affected networks when possible.
* Large untruncated UDP responses can be fragmented or dropped on other paths. The report highlights observed responses above conservative path limits.
* The fragmentation indication is a heuristic based on the observed DNS message size. Confirm suspected packet loss with a packet capture when necessary.
* IPv6 tests run automatically only when the script detects an IPv6 default route. Use `DNS_DIAG_IPV6=force` to override the detection.
* The DS and DNSKEY queries are basic checks, not a complete DNSSEC validation or key lifecycle audit.
* The output can contain complete TXT records, server addresses, and local system or resolver details. Review it before sharing externally.
* Large name server sets can generate many DNS queries. Use the script responsibly and respect provider rate limits.

Relevant standards:

* [RFC 6891: Extension Mechanisms for DNS](https://www.rfc-editor.org/rfc/rfc6891.html)
* [RFC 7766: DNS Transport over TCP](https://www.rfc-editor.org/rfc/rfc7766.html)
* [RFC 7873: Domain Name System Cookies](https://www.rfc-editor.org/rfc/rfc7873.html)

---

## License

This script is covered under the repository's main [MIT License](../LICENSE).
