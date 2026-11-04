#!/bin/bash

# Check if a file path argument has been provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_dhcp_xml_file>"
    exit 1
fi

# Assign the first argument as the DHCP XML file path
DHCP_XML_FILE="$1"

# Check if the specified file exists
if [ ! -f "$DHCP_XML_FILE" ]; then
    echo "Error: File $DHCP_XML_FILE does not exist."
    exit 2
fi

# Define the critical DHCP options to check for
declare -a CRITICAL_OPTIONS=(1 3 6 15 51)

echo "# checking for missing DHCP options in $DHCP_XML_FILE #"

# Extract ScopeIds
scope_ids=$(xmllint --xpath '//Scope/ScopeId/text()' "$DHCP_XML_FILE" 2>/dev/null)

# Convert scope IDs to an array
IFS=$'\n' read -rd '' -a scope_array <<<"$scope_ids"

# Iterate over each scope
for scope_id in "${scope_array[@]}"; do
    echo -n " $scope_id"
    missing_options=()
    
    for option_id in "${CRITICAL_OPTIONS[@]}"; do
        # Special handling for Option 1 (Subnet Mask) as it might not follow the OptionValue structure
        if [[ "$option_id" == "1" ]]; then
            subnet_mask=$(xmllint --xpath "string(//Scope[ScopeId='$scope_id']/SubnetMask)" "$DHCP_XML_FILE" 2>/dev/null)
            if [[ -z "$subnet_mask" ]]; then
                missing_options+=("$option_id")
            fi
        else
            # Check for OptionValues with the given OptionId
            option_exists=$(xmllint --xpath "count(//Scope[ScopeId='$scope_id']/OptionValues/OptionValue[OptionId='$option_id'])" "$DHCP_XML_FILE" 2>/dev/null)
            if [[ "$option_exists" == "0" ]]; then
                missing_options+=("$option_id")
            fi
        fi
    done
    
    # Report missing options for the scope, if any
    if [ ${#missing_options[@]} -ne 0 ]; then
        echo " is missing critical options: ${missing_options[*]}"
    else
        echo " has all critical options."
    fi
done

echo "# check complete #"
