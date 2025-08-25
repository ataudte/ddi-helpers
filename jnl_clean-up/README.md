# jnl_clean-up.sh

## Description
This script safely removes **BIND journal (.jnl) files** from a BlueCat DNS server environment.  
It stops the `named` service, backs up all `.jnl` files to a temporary folder, and deletes them from the live configuration directory.

---

## Usage
```bash
./jnl_clean-up.sh
```

No arguments are required.  
The script operates on a fixed directory:
```
/replicated/jail/named/var/dns-config/dbs/
```

---

## Features
- **Logging**  
  - All actions logged with timestamps to:
    ```
    jnl_clean-up_<timestamp>.log
    ```

- **Service Control**  
  - Stops the `named` service before modifying journal files:
    ```
    PsmClient node set dns-enable=0
    ```

- **Backup**  
  - Copies all `.jnl` files to:
    ```
    /tmp/jnl-backup/
    ```

- **Cleanup**  
  - After successful backup, deletes `.jnl` files from the live directory.  

- **Error Handling**  
  - Exits if the directory does not exist or if service stop fails.  
  - Logs both success and failure messages.  

---

## Output
- **Backup Directory**  
  - `/tmp/jnl-backup/` containing original `.jnl` files.  

- **Log File**  
  - `jnl_clean-up_<timestamp>.log` with a step‑by‑step execution trace.  

---

## Requirements
- Bash  
- BlueCat BAM/BDDS environment with `PsmClient` available  
- Tools: `find`, `cp`, `tee`  

---

## Notes
- Run only in maintenance windows: `.jnl` files contain dynamic DNS updates not yet flushed to zone files.  
- Always validate after cleanup that `named` can restart successfully and that DNS zones are consistent.  
- Backup files remain under `/tmp/jnl-backup/` until manually cleared.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
