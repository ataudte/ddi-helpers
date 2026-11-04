# get_ldap_groups.pl

## Description
A Perl script that connects to an **LDAP/Active Directory** server, searches for a given user, and prints all groups (`memberOf`) the user belongs to.

---

## Usage
Edit the script to set your environment values:
```perl
my $ldap_server = "ldap://<server-ip-or-host>";
my $user       = "<username>";       # sAMAccountName
my $password   = "<password>";
my $adDomain   = "<ad-domain>";      # e.g. corp.example.com
my $base_dn    = "dc=corp,dc=example,dc=com";
```

Run:
```bash
perl get_ldap_groups.pl
```

---

## Features
- Connects to an LDAP/AD server.  
- Authenticates with `username@domain`.  
- Searches for the user by `sAMAccountName`.  
- Prints distinguished name (DN) of the user and all groups they belong to.  

---

## Example Output
```
Groups for CN=Test User,CN=Users,DC=corp,DC=example,DC=com:
 - CN=Domain Admins,CN=Users,DC=corp,DC=example,DC=com
 - CN=VPN Users,CN=Users,DC=corp,DC=example,DC=com
 - CN=IT,CN=Users,DC=corp,DC=example,DC=com
```

---

## Requirements
- Perl  
- Perl module: `Net::LDAP`  

Install `Net::LDAP` on Debian/Ubuntu:
```bash
sudo apt-get install libnet-ldap-perl
```

---

## Notes
- Default script values are placeholders; adjust to match your LDAP/AD environment.  
- Credentials are currently stored in the script — for production use, change to secure input (e.g., environment variables).  
- Works best in Active Directory but is compatible with generic LDAP servers that use `memberOf`.  

---

## License
This script is covered under the repository’s main [MIT License](../LICENSE).
