# pw_check.sh

## Description
This script verifies which of up to **three provided passwords** are valid for logging into a list of BlueCat DNS/DHCP Servers (BDDS) over SSH.  
It iterates through servers from a file, attempts password authentication, and logs the results.

---

## Usage
```bash
./pw_check.sh <server-list>
```

- **server-list** → File containing one server hostname or IP per line.

Example:
```bash
./pw_check.sh bdds_list.txt
```

---

## Features
- Prompts the user securely for **three passwords**.  
- For each server in the list:
  - Tests SSH connectivity on port 22.  
  - Tries all three passwords in sequence.  
  - Logs whether access succeeded or failed.  
- Logs detailed debug and error messages.  
- Saves results to a summary file.  

---

## Output
- **Log file**:
  ```
  pw_check.log
  ```
  Contains detailed debug and error information.

- **Results file**:
  ```
  password_test_results.txt
  ```
  Contains summary results of password validity per server.

---

## Requirements
- Bash / POSIX shell  
- `ssh` client  
- `timeout` command  
- Access to the BDDS servers over port 22  

---

## Notes
- Input passwords are prompted securely (not echoed).  
- Do not use in production environments without caution — it will attempt multiple SSH logins.  
- Useful for verifying password changes or bulk credential audits.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
