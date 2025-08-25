# random_nsupdate.dh

## Description
This script performs randomized **dynamic DNS updates** using the `nsupdate` utility.  
It continuously generates random hostnames and IPv4 addresses and adds them to a specified DNS zone on a given server for a defined duration.

---

## Usage
```bash
./random_nsupdate.dh <time_to_run_in_seconds> <dns_server_ip> <dns_zone_name>
```

- **time_to_run_in_seconds** → How long the script should run (in seconds).  
- **dns_server_ip** → Target DNS server IP address.  
- **dns_zone_name** → DNS zone where records should be added.  

Example:
```bash
./random_nsupdate.dh 60 192.168.1.10 example.com
```
This runs for 60 seconds, adding random A records into `example.com` on server `192.168.1.10`.

---

## Features
- **Random hostname generator**  
  - 5-character alphanumeric string.  
- **Random IPv4 generator**  
  - Produces an address like `X.Y.Z.W` with each octet between 0–255.  
- **Dynamic updates**  
  - Creates a temporary `nsupdate` input file with commands:
    ```
    server <dns_server>
    zone <dns_zone>
    update add <hostname>.<zone>. 300 A <ip_address>
    send
    ```
  - Executes with `nsupdate -v`.  
- **Logging**  
  - Prints success or failure messages to the console for each update.  

---

## Output
- Dynamic A records added to the specified DNS zone on the server.  
- Console messages such as:
  ```
  Successfully added ab12c.example.com with IP 192.168.42.99
  Failed to add xy7pq.example.com
  ```

---

## Requirements
- Bash  
- Tools: `nsupdate`, `mktemp`, `tr`, `head`  

---

## Notes
- Requires that the DNS server accepts dynamic updates for the specified zone.  
- Run in a test/lab environment — this script can flood zones with random records.  
- Use with caution in production.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
