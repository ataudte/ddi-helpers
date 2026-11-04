#!/usr/bin/perl

use strict;
use warnings;
use Net::LDAP;

# LDAP server details
my $ldap_server = "ldap://10.0.187.207";
my $user = "testuser"; # Used for both binding and searching
my $password = "testpassword";
my $adDomain = "mrddi.corp";
my $base_dn = "dc=mrddi,dc=corp";

# Construct the bind user in the format "username@domain"
my $binduser = $user . "@" . $adDomain;

# Create a connection to LDAP server
my $ldap = Net::LDAP->new($ldap_server) or die "Error connecting to $ldap_server: $@";

# Bind (authenticate) with credentials
my $mesg = $ldap->bind($binduser, password => $password);

# Check if bind was successful
if ($mesg->code) {
    die "Bind error: ", $mesg->error;
}

# Search for the user
# The filter uses the sAMAccountName attribute, which is the pre-Windows 2000 logon name
$mesg = $ldap->search(
    base   => $base_dn,
    filter => "(sAMAccountName=$user)",
    attrs  => ['memberOf']
);

# Check if the search was successful
if ($mesg->code) {
    die "Search error: ", $mesg->error;
}

# Process search results
foreach my $entry ($mesg->entries) {
    my $user_dn = $entry->dn;
    print "Groups for $user_dn:\n";
    foreach my $group ($entry->get_value('memberOf')) {
        print " - $group\n";
    }
}

# Unbind from LDAP server
$ldap->unbind;
