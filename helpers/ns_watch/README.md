# ns_watch.sh

## Description
A lightweight console DNS status monitor for macOS, compatible with Bash 3.2. It checks one or more DNS zones and displays coloured traffic-light dots, name-server addresses, SOA serials, and query times.

For each zone, the script looks up NS records through the default resolver, resolves each name server's IPv4/IPv6 addresses, and queries the servers directly for SOA records with recursion disabled. Differences between returned SOA serials are highlighted in red.

Inspired by Carsten's [DNS-traffic-lights](https://github.com/cstrotm/DNS-traffic-lights).

---

## Usage
Make the script executable, then monitor a single zone:

```bash
chmod +x ns_watch.sh
./ns_watch.sh example.com -d
```

Monitor zones from a file, with a five-second pause between completed checks:

```bash
./ns_watch.sh domains.txt -f 5
```

Show help:

```bash
./ns_watch.sh --help
```

Syntax:

```text
./ns_watch.sh <domain|file> <-d|-f> [interval]
```

| Argument | Description |
| --- | --- |
| `<domain\|file>` | A fully qualified domain name (FQDN), or a text-file path. Must come before the mode flag. |
| `-d`, `--fqdn` | Treat the first argument as a single domain name. |
| `-f`, `--file` | Read domain names from the file given as the first argument. |
| `[interval]` | Positive integer: seconds to wait after each completed check. Default: `10`. |

Press **q**, **Q**, **Esc**, or **Ctrl+C** to stop.

---

## Requirements

- macOS with Bash 3.2 or later.
- `dig` and standard command-line utilities, including `awk`, `sed`, `grep`, `sort`, `tr`, `paste`, `wc`, `head`, `date`, `mktemp`, `stty`, and `tput`.
- An interactive terminal with ANSI colour support and a font that displays `●`. Standard input and output must both be connected to a terminal.
- Network access to the configured DNS resolver and the name servers being checked.

No additional language modules or graphics support are required.

---

## Input / Output

**Input:** A single domain name or a text file containing one domain name per line. Example `domains.txt`:

```text
# Zones to monitor
example.com
example.org  # Inline comments are supported

example.net
```

Blank lines and `#` comments are ignored. Domain names are converted to lowercase, trailing dots are removed, and duplicates are checked only once. Invalid entries in a file are reported and skipped; monitoring stops if no valid names remain. An invalid name in single-domain mode is rejected.

**Output:** A live terminal display showing:

- A traffic light and DNS response status for each zone.
- Each discovered name server and its IPv4/IPv6 addresses.
- Its SOA serial and the successful SOA query's response time in milliseconds, or an error such as `TIMEOUT`, `NO ADDRESS`, or `NO SOA`.
- A countdown until the next check.

| Light | Meaning |
| --- | --- |
| Green — OK | The NS lookup returns `NOERROR`, all discovered name servers return SOA records, and their serials match. A `NOERROR` response with no NS records also shows green, with a separate note. |
| Yellow — WARNING | The NS lookup returns `NXDOMAIN`, only some name servers return SOA records, or returned SOA serials differ. |
| Red — FAILURE | The NS lookup fails, for example with `SERVFAIL`, `REFUSED`, or a timeout; or NS records are found but none of the name servers returns an SOA record. |

Only the active light is coloured; the other two dots remain grey. Differing SOA serials and individual server errors appear in red.

Results are displayed in the terminal. The script creates temporary working files and removes them on exit; it does not save a report or log.

---

## Notes

- Use zone names that have NS records. A hostname inside a zone may return `NOERROR` without NS records; its green light does not confirm name-server availability or matching serials.
- Each zone is checked in a separate background job. The next cycle starts after all jobs finish and the configured interval has elapsed, so DNS query time adds to the refresh period.
- Each `dig` call uses `+time=2 +tries=1`. For each name server, the script tries IPv4 addresses first, then IPv6, stopping at the first successful SOA response. It does not test every address after one succeeds.
- Input names use ASCII letters, digits, and hyphens in labels of up to 63 characters, with a maximum total length of 253 characters excluding a trailing dot. Labels cannot begin or end with a hyphen, and the final label cannot be entirely numeric. A single-label TLD must include a trailing dot, for example `de.`.
- Monitoring requires an interactive terminal; piping or redirecting its output is not supported.

---

## License
Refer to the repository's main [LICENSE](../LICENSE) for licensing terms.

