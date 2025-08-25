#!/bin/bash

# Check if two parameters are passed
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <normalized-zone-file> <subzones-file>"
    exit 1
fi

ZONE_FILE="$1"
SUBZONES_FILE="$2"

# Extract zone name from the first column of the SOA record
ZONE_NAME=$(awk '$4 == "SOA" {print $1; exit}' "$ZONE_FILE")
DIR_NAME="named_${ZONE_NAME%.}"

# Create output directory for the generated files
mkdir -p "$DIR_NAME"

# Function to generate SOA record
generate_soa_record() {
    local subzone="$1"
    local serial=$(date +"%Y%m%d00")
    echo "$subzone 3600 IN SOA dns.${subzone} hostmaster.${subzone} ${serial} 86400 7200 604800 3600"
    echo "$subzone 3600 IN NS dns.${subzone}"
    echo "dns.${subzone} 3600 IN AAAA 2001:db8::53"
}

# Create zone files for each subzone
while read -r SUBZONE; do
    SUBZONE_FILE="${DIR_NAME}/${SUBZONE%.}"
    
    # Write SOA record for the subzone
    generate_soa_record "$SUBZONE" > "$SUBZONE_FILE"
    
    # Extract records belonging to the subzone from the zone file
    awk -v subzone="$SUBZONE" '$1 ~ subzone {print}' "$ZONE_FILE" >> "$SUBZONE_FILE"
done < "$SUBZONES_FILE"

# Remove child subzone records from parent subzones
while read -r PARENT_SUBZONE; do
    PARENT_SUBZONE_FILE="${DIR_NAME}/${PARENT_SUBZONE%.}"
    
    # Check for child subzones
    while read -r CHILD_SUBZONE; do
        if [[ "$CHILD_SUBZONE" == *"$PARENT_SUBZONE"* && "$CHILD_SUBZONE" != "$PARENT_SUBZONE" ]]; then
            CHILD_SUBZONE_FILE="${DIR_NAME}/${CHILD_SUBZONE%.}"
            
            # Remove child subzone records from the parent subzone
            grep -v -Ff "$CHILD_SUBZONE_FILE" "$PARENT_SUBZONE_FILE" > "${PARENT_SUBZONE_FILE}.tmp"
            mv "${PARENT_SUBZONE_FILE}.tmp" "$PARENT_SUBZONE_FILE"
        fi
    done < "$SUBZONES_FILE"
done < "$SUBZONES_FILE"

# Create named.conf for the zone and subzones
NAMED_CONF="${DIR_NAME}/named_${ZONE_NAME%.}.conf"

# Add master statement for each subzone
while read -r SUBZONE; do
    echo "zone \"${SUBZONE%.}\" { type master; file \"${SUBZONE%.}\"; };" >> "$NAMED_CONF"
done < "$SUBZONES_FILE"

# Extract records not in any subzone
OTHER_RECORDS="${DIR_NAME}/${ZONE_NAME%.}_other.zone"
generate_soa_record "$ZONE_NAME" > "$OTHER_RECORDS"
grep -v -Ff <(awk '{print $1}' "$SUBZONES_FILE") "$ZONE_FILE" >> "$OTHER_RECORDS"

# Add master statement for non-split zone file
echo "zone \"$ZONE_NAME\" { type master; file \"${OTHER_RECORDS##*/}\"; };" >> "$NAMED_CONF"

echo "Zone files and configuration generated in directory: $DIR_NAME"
