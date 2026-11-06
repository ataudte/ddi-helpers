# dns_watch.sh

## Description
Monitors DNS and WHOIS records of a list of domains on macOS, detects drift and possible hijacking attempts, and alerts within seconds of a change.
Runs in an endless loop as a live terminal dashboard, so it can stay open on a screen for monitoring.

What it checks:
- **DNS records** (default `NS A AAAA MX TXT CAA`, configurable per domain), queried directly on the domain's authoritative nameservers. Nothing is cached, so changes are visible immediately.
- **Registry delegation** (`PARENT_NS`): the nameservers the TLD registry points to. A change here is the classic registrar hijack signal and is detected without waiting for WHOIS.
- **WHOIS** (every 6 h by default): registrar, EPP status codes (transfer locks, pending transfer, hold), nameservers and expiry date.

Every change is reported per value as `ADDED`, `REMOVED` or `MODIFIED` and gets a severity:

| Severity | Triggers |
|---|---|
| CRITICAL | NS, parent NS, DS or DNSKEY change, domain becomes NXDOMAIN, WHOIS registrar or nameserver change, transfer lock removed, pending transfer / hold / redemption status (possible hijack) |
| HIGH | A, AAAA, CNAME, MX, CAA change, SPF / DMARC / DKIM / verification TXT change, lookups failing, domain expiring soon |
| MEDIUM | Other TXT or record changes, other WHOIS status changes |
| LOW | WHOIS expiry date change (renewal), lock added, lookups recovered |

Alerts are shown as macOS notifications (Notification Center, with sound; a different sound for CRITICAL).

---

## Usage
```bash
chmod +x dns_watch.sh
./dns_watch.sh                           # uses dns_watch_domains.csv next to the script
./dns_watch.sh /path/to/other_list.csv   # or a different domain list
```

On first start, a sample `dns_watch_domains.csv` is created. Edit it and start the script again.

Dashboard keys:

| Key | Action |
|---|---|
| `q` / `Q` | Quit |
| `r` / `R` | Check all domains now |
| `a` / `A` | Acknowledge drifts (sets DRIFT / ALERT back to OK) |

Settings are variables at the top of the script:

| Setting | Default | Meaning |
|---|---|---|
| `INTERVAL` | `30` | Seconds between DNS checks |
| `WHOIS_INTERVAL` | `21600` | Seconds between WHOIS checks (registries rate-limit WHOIS) |
| `DEFAULT_TYPES` | `NS A AAAA MX TXT CAA` | Record types when the CSV leaves them empty |
| `RESOLVER` | `9.9.9.9` | Resolver used only to locate the authoritative nameservers |
| `MAX_PARALLEL` | `8` | Domains checked at the same time |
| `ERROR_THRESHOLD` | `3` | Failed checks in a row before status ERROR |
| `EXPIRY_WARN_DAYS` | `30` | Warn when the registration expires within this many days |
| `ALERT_MIN_SEVERITY` | `LOW` | Lowest severity that shows a notification |

---

## Requirements
- Bash 3.2+ (default on macOS)
- macOS built-in tools: `dig`, `whois`, `osascript`, BSD `date`
- External modules: none
- Vendor-specific dependencies: none

---

## Input / Output
- **Input:** `dns_watch_domains.csv` with one domain per line: domain, record types (space separated, empty = default), WHOIS check (`yes`/`no`). Lines starting with `#` are ignored.

  ```csv
  domain,types,whois
  example.com,,yes
  www.example.com,CNAME A AAAA,no
  _dmarc.example.com,TXT,no
  ```

- **Output:** one results file per domain in `dns_watch_results/<domain>.txt`, containing:
  - **Status header:** status (`NEW`, `OK`, `DRIFT`, `ALERT`, `ERROR`), status since, last check, unacknowledged severity, drift count, record count, expiry date, last event.
  - **Baseline:** the last known records, used for the next comparison.
  - **History:** baseline captures, drifts, status changes, expiry warnings and acknowledgements (last 2000 lines).

  ```text
  === HISTORY ===
  2025-10-05 13:05:32  BASELINE  baseline captured (6 records)
  2025-10-05 13:05:32  STATUS    NEW -> OK
  2025-10-05 14:21:07  DRIFT     [HIGH] MODIFIED A: 1.1.1.1 -> 2.2.2.2
  2025-10-05 14:21:07  DRIFT     [CRITICAL] MODIFIED PARENT_NS: ns1.example.net. -> ns1.evil.example.
  2025-10-05 14:21:07  STATUS    OK -> ALERT
  2025-10-05 14:30:00  ACK       drifts acknowledged, status -> OK
  ```

  Alerts are shown as macOS notifications; nothing else is written.

---

## Notes
- **First run** only captures baselines; alerts start from the second check.
- **Detection time** is at most `INTERVAL` seconds for DNS. WHOIS changes are detected within `WHOIS_INTERVAL`, which is why registry delegation (`PARENT_NS`) is checked on every DNS cycle.
- **Accepted changes:** after a drift the new records become the baseline. The domain stays `DRIFT` / `ALERT` on screen until acknowledged with `a`.
- **Failed lookups** keep the previous records, so a network outage never shows up as deleted records. Status turns `ERROR` only after `ERROR_THRESHOLD` failures in a row.
- **Registry delegation and WHOIS** are only checked for registered domains (zone apex), not for subdomains.
- **Load balancers and CDNs:** names whose answers rotate between checks (large load-balancer pools, some CDNs) will report frequent drifts. Monitor only their `CNAME` instead.
- **WHOIS coverage** depends on the registry. Some registries, such as DENIC for `.de`, do not publish registrar or expiry data, so expiry warnings are unavailable for those domains.
- **macOS only:** date parsing (`date -j`) and notifications (`osascript`) are macOS-specific. The first notification may ask you to allow notifications for "Script Editor" in System Settings.
- **References:**
  - [RFC 1034](https://www.rfc-editor.org/rfc/rfc1034) / [RFC 1035](https://www.rfc-editor.org/rfc/rfc1035): DNS
  - [RFC 3912](https://www.rfc-editor.org/rfc/rfc3912): WHOIS protocol
  - [RFC 5731](https://www.rfc-editor.org/rfc/rfc5731): EPP domain status values
  - [ICANN EPP status codes](https://www.icann.org/epp)

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
