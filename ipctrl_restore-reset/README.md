# ipctrl_restore-reset.sh

## Description
This script restores an IPControl database from a provided SQL dump (packaged as a `.zip` file).  
It unpacks the SQL, stops the InControl service, starts MySQL, and loads the SQL dump into the database.

---

## Usage
```bash
./ipctrl_restore-reset.sh <path_to_sql.zip_file>
```

Example:
```bash
./ipctrl_restore-reset.sh /tmp/ipcontrol-backup-20250101.sql.zip
```

---

## Features
- Validates that a `.zip` file argument is provided.  
- Unpacks the archive to extract the `.sql` file.  
- Moves the `.sql` file into the MySQL bin directory:
  ```
  /opt/incontrol/mysql/bin
  ```
- Stops the InControl service:
  ```
  /opt/incontrol/etc/incontrol stop
  ```
- Starts the MySQL server:
  ```
  /opt/incontrol/etc/mysqld_start
  ```
- Waits for MySQL startup before continuing.  
- Prepares to restore the SQL dump into the InControl database.  
- Logs all actions into a timestamped logfile created in the script directory.  

---

## Output
- **Log file**:
  ```
  ipctrl_restore-reset_<timestamp>.log
  ```
- Console messages showing unpacking, service stop/start, and SQL file movement.  

---

## Requirements
- Bash  
- BlueCat IPControl environment with:
  - `/opt/incontrol/etc/incontrol` (service scripts)  
  - `/opt/incontrol/etc/mysqld_start`  
  - `/opt/incontrol/mysql/bin/mysql`  
- Tools: `unzip`, `mv`, `sleep`  

---

## Notes
- Default database user/password are set in the script (`incadmin/incadmin`). Update as needed.  
- The SQL dump filename is derived from the `.zip` archive name.  
- Run during maintenance windows — this process **stops InControl services**.  
- Ensure the `.zip` contains a valid `.sql` file.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
