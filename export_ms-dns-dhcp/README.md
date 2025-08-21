# export_ms-dns-dhcp.ps1

## Description
This PowerShell script exports both **DNS and DHCP configuration** from a Microsoft Windows Server and packages the results into a ZIP archive for handover, backup, or migration purposes.

It collects:
- **DHCP configuration**:
  - Full export via `netsh` and `Export-DhcpServer`
  - DHCP failover configuration
- **DNS configuration**:
  - Zone inventory and server configuration
  - Named.conf-style output
  - Primary zone files, saved into `dbs/`
  - Remote Domain Controller (DC) zone lists
  - Local vs. remote zone comparisons

All collected data is archived into a ZIP file:
```
MS-DNS-DHCP_<hostname>_<timestamp>.zip
```

---

## Usage
Run from an elevated PowerShell session on a Microsoft DNS/DHCP server:

```powershell
.\export_ms-dns-dhcp.ps1
```

---

## Requirements
- Windows Server with **DNS and/or DHCP roles** installed.  
- PowerShell 5.1+  
- RSAT or built-in DNS/DHCP management tools:  
  - `Export-DhcpServer`  
  - `netsh`  

---

## Input / Output
- **Input:** None (runs directly on the server).  
- **Output (default location: `C:\DDI_Output`):**
  - DHCP configuration exports (`<hostname>_dhcp*`)  
  - DNS zone inventory (`<hostname>_enumzones.txt`)  
  - Server configuration dump  
  - Zone files in `dbs/`  
  - Remote vs local zone comparisons  
  - Consolidated ZIP archive:  
    ```
    MS-DNS-DHCP_<hostname>_<timestamp>.zip
    ```
  - Log file in script directory:  
    ```
    export_ms-dns-dhcp_<timestamp>.log
    ```

---

## Notes
- Ensure you run the script as **Administrator**.  
- Exported files are organized under `C:\DDI_Output`.  
- The ZIP archive provides a portable snapshot for migration or disaster recovery.  
- DHCP exports require the `DHCP Server` role or RSAT DHCP tools.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).  
