# pw_mgmt.sh

## Description
Bulk **password rotation** for BlueCat DNS/DHCP Servers (BDDS).  
For each BDDS listed in an input file, the script:
1) Validates SSH access with the **current root password**.  
2) Connects via SSH and runs `passwd -q <user>` non‑interactively to set a **new password** for the target user.  
3) If the target user is `root`, it **re‑validates** SSH with the **new** password.  
All steps are logged.

> This script is intended for controlled maintenance windows. Use with care.

---

## Usage
```bash
./pw_mgmt.sh <server-list>
```
- **server-list**: File with one BDDS hostname or IP per line.

During execution you will be **prompted** for:
- **Current root password** on the BDDS (`bddsrootpwd`)
- **Target username** whose password should be changed (`bddsuser`, e.g. `root`)
- **New password** to set for that user (`bddsnewpwd`)

---

## What it does (per server)
- Checks basic reachability.
- Validates SSH login for **root** using the current root password (`testssh` helper).
- Runs a remote command to change the password for `<bddsuser>`:
  ```sh
  echo -e "<newpass>\n<newpass>" | passwd -q <bddsuser>
  ```
  (piped non‑interactively via `/usr/bin/script` and `ssh`).
- If `<bddsuser>` is `root`, the script attempts a fresh SSH login with the **new** password to confirm success.
- Logs success/failure with timestamps.

---

## Output
- **Log file** (created alongside the script):
  ```
  pw_mgmt.log
  ```
  Contains timestamped `DEBUG`, `ERROR`, and status messages for each host.

- **Console**: Progress lines such as:
  ```
  # ----- # validating root credentials for bdds01
  # ----- # changing password for user root on bdds01
  # ----- # validating new root credentials for bdds01
  # ----- # done with bdds01
  ```

---

## Requirements
- POSIX shell
- `ssh` client
- `/usr/bin/script` (for controlled stdin to `ssh`)
- Remote `passwd` utility
- `egrep`, `tee`, `sleep`

---

## Notes & Safety
- The script **does not** read passwords from the command line; it prompts interactively.
- Make sure PAM/SSH allows password authentication for the operation (key‑only hosts will fail).
- If a server is unreachable or SSH validation fails, it is **skipped** and logged.
- Consider testing on a small subset first.

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
