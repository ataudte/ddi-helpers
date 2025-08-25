#!/bin/bash

# Check if two files are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <named1> <named2>"
    exit 1
fi

named1=$1
named2=$2

# Function to extract zone details
extract_zone_details() {
    local conf_file=$1
    local zone=$2
    local details=$(grep -A 10 -i "zone \"$zone\"" "$conf_file")

    local type=$(echo "$details" | grep -i "type" | awk '{print $2}' | tr -d ';')

    # Skip zones of type "hint" and the root zone "."
    if [[ "$type" == "hint;" ]] || [[ "$zone" == "." ]]; then
        return
    fi

    # Output zone details
    echo "$conf_file zone:       $zone" >&2
    echo "$conf_file type:       $type" >&2

    case $type in
        "master")
            local file=$(echo "$details" | grep -i "file" | awk '{print $2}' | tr -d '";')
            echo "$conf_file file:       $file" >&2
            ;;
        "slave")
            local file=$(echo "$details" | grep -i "file" | awk '{print $2}' | tr -d '";')
            local masters_block=$(echo "$details" | awk '/masters {/,/};/')
            local masters=$(echo "$masters_block" | grep -oE '([0-9]{1,3}[\.]){3}[0-9]{1,3}')
            echo "$conf_file file:       $file" >&2
            echo "$conf_file masters:    $masters" >&2
            ;;
        "forward")
            local forwarders_block=$(echo "$details" | awk '/forwarders {/,/};/')
            local forwarders=$(echo "$forwarders_block" | grep -oE '([0-9]{1,3}[\.]){3}[0-9]{1,3}')
            echo "$conf_file forwarders: $forwarders" >&2
            ;;
    esac
    
    # Return the zone type
   echo "$type"
}

# Extract zone names from both files, ignoring specific zones and ensuring lines start with "zone"
zones_named1=$(grep -Ei '^\s*zone\s+"' "$named1" | grep -v "disable-empty-zone" | grep -viE 'zone\s+"localhost"|zone\s+"127.IN-ADDR.ARPA"|zone\s+"0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"|zone\s+"."' | awk '{print $2}' | tr -d '"' | tr '[:upper:]' '[:lower:]')
zones_named2=$(grep -Ei '^\s*zone\s+"' "$named2" | grep -v "disable-empty-zone" | grep -viE 'zone\s+"localhost"|zone\s+"127.IN-ADDR.ARPA"|zone\s+"0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa"|zone\s+"."' | awk '{print $2}' | tr -d '"' | tr '[:upper:]' '[:lower:]')

# Compare and extract details for common zones
for zone in $zones_named1; do
    if echo "$zones_named2" | grep -wxi "$zone"; then
        # Output for each exact split-horizon zone found
        type1=$(extract_zone_details "$named1" "$zone")
        type2=$(extract_zone_details "$named2" "$zone")
        # Check if zone types match and are not skipped
        if [[ "$type1" == "$type2" ]]; then
            echo -e "###\n### TYPE FOR $zone MATCHES IN $named1 AND $named2 ###\n###"
        fi
        echo "----"
    fi
done
