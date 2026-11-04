# bam_access.sh

## Description
This script automates direct user management on the BlueCat Address Manager (BAM) PostgreSQL backend. It checks for the existence of key users (`admin` or `bluecat`), updates their password to a predefined MD5 hash, or creates the `bluecat` user when missing. It is intended for controlled administrative recovery scenarios where API access is unavailable.

---

## Usage
Run the script with Bash on the BAM server (requires local PostgreSQL access):

```bash
sudo ./bam_access.sh
```

The script:
- Locates the `admin` or `bluecat` user in the BAM internal database.
- Updates the password if the user exists.
- Creates the `bluecat` user when neither exists.
- Outputs actions performed directly to the console.

---

## Requirements
- Bash (Linux environment)
- Local access to the BAM PostgreSQL database
- PostgreSQL client utilities (`psql`)
- Permissions to write into the BAM database
- BlueCat Address Manager installation using the `proteusdb` PostgreSQL schema

---

## Input / Output
- **Input:**  
  No external input files. All required variables (DB name, DB user, password hash) are embedded in the script.

- **Output:**  
  - Console messages indicating whether users were found, updated, or created.
  - Changes applied directly to BAM's internal PostgreSQL tables (`entity`, `hiddenpassword`).

---

## Notes
- The fixed password hash corresponds to the BlueCat BAM legacy MD5 password format.
- This script bypasses the public API and writes directly to the BAM database. Use with caution.
- Requires shell access to the BAM server — this is not an API‑level recovery tool.
- Review vendor guidelines before modifying internal BAM schema.

---

## License
This script is covered under the repository’s main MIT License.
