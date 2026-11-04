# dns_ttl_watch.sh

## Description
Interactive DNS watch tool that *paces itself by the observed TTL*. It runs repeated `dig` queries for a given FQDN and record type, prints the current TTL and answer values, then sleeps for **exactly the maximum TTL seen** before querying again. This is useful for seeing when a cached RRset expires and when answers (or TTLs) change.

It supports two query modes:
- **Recursive mode (default):** query a specific recursive resolver (`-s`) or your system default resolver
- **Root/trace mode (`-r`):** run `dig +trace` and extract TTLs/values from the trace output (resolver selection via `-s` is disabled in this mode)

---

## Usage
Show help:

```bash
./dns_ttl_watch.sh --help
```

Default (A record, system resolver):

```bash
./dns_ttl_watch.sh example.com
```

Query a specific recursive resolver:

```bash
./dns_ttl_watch.sh example.com -s 1.1.1.1
```

Query a specific RR type:

```bash
./dns_ttl_watch.sh example.com -t AAAA
```

Trace from the root:

```bash
./dns_ttl_watch.sh example.com -t A -r
```

Quit cleanly:
- During the sleep phase, press **q** to stop.
- Or send SIGINT (Ctrl+C).

---

## Requirements
- Bash
- `dig` (BIND utilities; package names typically `dnsutils` or `bind-utils`)
- Common tools: `awk`, `sed`, `paste`, `tee`, `stty`

---

## Input / Output
- **Input:**
  - `FQDN` (required)
  - `-t RECORD_TYPE` (optional, defaults to `A`)
  - `-s DNS_SERVER` (optional, recursive mode only)
  - `-r` (optional, enables `dig +trace` root mode)

- **Output:**
  - Timestamped log lines to stdout
  - A log file next to the script: `dns_ttl_watch.log`
  - Each iteration prints something like:
    - `TTL=<max_ttl> VALUES=<one-line values>`

---

## Notes
- The script uses the **maximum TTL** seen in the current response/trace and sleeps that many seconds (minimum 1s).
- In `-r` mode the output reflects `dig +trace` behavior; TTLs/values can differ from what a recursive resolver returns.
- Intended for troubleshooting and analysis, not for production monitoring.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
