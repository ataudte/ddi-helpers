# dns_cutover.ps1

## Description
PowerShell script to automate a **DNS cutover** on Microsoft Windows DNS Server.  
It reads a CSV with zone configuration and global settings, creates a full backup of the current DNS state, applies changes (secondary zones, forwarders, removals), and logs all actions for audit/handover.  

A complementary script **dns_cutover_restore.ps1** is provided to restore the DNS server to its previous state from the backup created during the cutover.

---

## Usage
Run from an **elevated PowerShell session** on a DNS server with the *DnsServer* module installed.

```powershell
# Example usage:
.\dns_cutover.ps1 -CsvPath .\zones.csv
```

Optional parameter:
```powershell
-BackupRoot <Path>   # Custom root folder for backup/logs (default: %SystemRoot%\dns\dns_cutover_YYYYMMDD-HHMMSS)
```

---

## CSV Format
The input CSV defines global forwarders, secondary zones, and conditional forwarders.

Example (`zones.csv`):
```csv
type,zone,addresses
global,,"1.2.3.4,5.6.7.8"
secondary,zone1.de,"9.8.7.6,5.4.3.2"
secondary,zone2.de,7.6.5.4
forwarder,zone3.de,"1.3.5.7,9.7.5.3"
forwarder,zone4.de,5.7.9.7
```

- **global**: Defines global forwarders.  
- **secondary**: Adds secondary zones with their master addresses.  
- **forwarder**: Adds conditional forwarders with addresses.  

---

## Requirements
- Windows Server with **DNS Server role**.  
- PowerShell with **DnsServer module** (`RSAT-DNS-Server` if running remotely).  
- Elevated (Administrator) PowerShell session.  

---

## Input / Output
- **Input:**  
  - `zones.csv` with DNS cutover configuration.  
- **Output:**  
  - Backup folder: `dns_cutover_<timestamp>` containing:  
    - Server/zone state before changes  
    - `dns_cutover_actions.log` with all executed actions  
  - Updated DNS server configuration after applying CSV.  

---

## Notes
- Always review the generated log file after execution.  
- The script ensures a backup is taken **before** applying any changes.  
- To restore from a backup, use the companion script:  
  ```powershell
  .\dns_cutover_restore.ps1 -BackupRoot <backup-folder>
  ```  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
