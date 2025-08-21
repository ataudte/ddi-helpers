# flush_jnl.sh

## Description
This script starts a temporary **BIND (named)** instance using the local `named.conf`,  
executes `rndc sync -clean` to flush all **.jnl journal files** into their corresponding **.db zone files**,  
and then shuts the server down cleanly.

It is useful for environments where you want to persist dynamic DNS updates (stored in `.jnl` files) into the zone files themselves.

---

## Usage
```bash
./flush_jnl.sh
```

Optional:
- Enable debug/foreground mode by setting `DEBUG_MODE=true` in the script.

---

## Features
- Automatically sets the working base directory (`$PWD`).  
- Looks for:
  - `dbs/` (zone database files)  
  - `named.conf` (server configuration)  
  - `rndc.key` and `rndc.conf` (created if missing)  
- Steps:
  1. Generates `rndc.key` if not present.  
  2. Creates `rndc.conf` from the key.  
  3. Ensures `named.conf` includes `rndc.key`.  
  4. Starts a temporary `named` instance.  
  5. Runs `rndc sync -clean` to flush `.jnl` into `.db`.  
  6. Shuts down the instance.  

---

## Output
- Updated `.db` zone files in `dbs/` with changes from their `.jnl` journals.  
- Backup of the original `named.conf` as `named.conf.bak`.  
- Console log messages indicating progress.  

---

## Requirements
- Bash  
- BIND utilities:
  - `named`
  - `rndc`
  - `rndc-confgen`  
- `awk`, `grep`, `cp`, `sudo`

---

## Notes
- Must be run on a system with BIND installed.  
- Requires sufficient privileges (may prompt for `sudo`).  
- Debug mode (`DEBUG_MODE=true`) keeps `named` in the foreground for troubleshooting.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
