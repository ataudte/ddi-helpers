# backup_ipctrl.ps1

## Description
This PowerShell script creates a **MySQL backup** of the BlueCat IPControl database.  
It runs `mysqldump.exe`, saves the export as a `.sql` file, compresses it into a `.zip`, and manages retention by deleting old backups.

---

## Usage
Run in PowerShell with:
```powershell
powershell.exe -ExecutionPolicy Bypass -File backup_ipcontrol.ps1
```

---

## Features
- **Configurable parameters**:
  - Backup volume and path (`C:\temp`)
  - MySQL bin path (`C:\Program Files\Diamond IP\InControl\mysql\bin`)
  - Database user/password (`incadmin/incadmin` by default)
  - Base filename (`ipcontrol`)
  - Retention time (default: 1209600 seconds = 14 days)

- **Ensures backup directory exists** (`C:\temp` by default).  
- **Deletes old backup files** older than retention period.  
- **Generates timestamped filenames**:
  - `ipcontrol-<timestamp>.sql`
  - `ipcontrol-<timestamp>.log`
  - `ipcontrol-<timestamp>.zip`
- **Runs mysqldump** with options:
  - `--opt --no-tablespaces`  
- **Compresses backup** into `.zip` file.  

---

## Output
- `.sql` dump of the `incontrol` database.  
- `.zip` archive containing the SQL dump.  
- `.log` file with dump operation output.  

All stored under the configured `$path` (default: `C:\temp`).

---

## Requirements
- Windows PowerShell  
- MySQL client tools (`mysqldump.exe`) in `$mysqlPath`  
- Permissions to access the `incontrol` database with the given credentials  

---

## Notes
- Update `$user` and `$password` variables with valid DB credentials before running.  
- Default retention is **14 days**; adjust `$keepFiles` (in seconds) as needed.  
- Backups are stored locally; integrate with scheduled tasks or external storage for resilience.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
