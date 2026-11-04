# dig_dump.sh

## Description
This script runs a `dig` DNS query against a specified DNS server while simultaneously capturing the associated DNS traffic with `tcpdump`.  
The result is a `.pcap` file for later analysis (e.g. in Wireshark) and a tcpdump log file.

---

## Usage
Run as root or with `sudo`:

```bash
sudo ./dig_dump.sh <dig options>
```

Example:
```bash
sudo ./dig_dump.sh example.com A
```

You will then be prompted to enter the **DNS server IP (IPv4 or IPv6)**.  
The script will:
1. Start `tcpdump` to capture DNS packets.  
2. Execute the `dig` query with your options.  
3. Stop `tcpdump` after a short delay.  
4. Save the capture and log.  
5. Launch Wireshark (if installed) to open the capture file.  

---

## Requirements
- Root privileges (or run with `sudo`)  
- Tools:
  - `dig`
  - `tcpdump`
  - `wireshark` (optional, for automatic viewing)  

---

## Input / Output
- **Input:**  
  - `dig` command options (e.g., query name, record type).  
  - DNS server IP (prompted interactively).  

- **Output:**  
  - `dns_capture.pcap` (DNS traffic capture)  
  - `tcpdump_log.txt` (capture log)  

---

## Notes
- The script overwrites existing `dns_capture.pcap` and `tcpdump_log.txt`.  
- Works for both IPv4 and IPv6 DNS servers.  
- If Wireshark is not installed, the capture remains available for later analysis.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
