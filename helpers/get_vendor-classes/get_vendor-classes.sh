#!/bin/bash

# Path to the XML file
XML_FILE="$1"

# Check if the XML file path is provided
if [ -z "$XML_FILE" ]; then
    echo "Usage: $0 path_to_xml_file"
    exit 1
fi

# Check if xmlstarlet is installed
if ! command -v xmlstarlet &> /dev/null; then
    echo "xmlstarlet could not be found, please install it."
    exit 1
fi

echo -e "\nVendor Classes (Excluding 'User' Type and Names Starting with 'Microsoft') and Their Details:"
echo "-------------------------------------------------------------------------------------------"
# Extract and list vendor classes excluding 'User' type and names starting with 'Microsoft'
xmlstarlet sel -t -m '//Class[Type="Vendor" and not(starts-with(Name, "Microsoft")) and not(Type="User")]' -v 'concat(Name, ": ", Description)' -n $XML_FILE

echo -e "\nGlobal Option Definitions for Each Valid Vendor Class:"
echo "------------------------------------------------------"
# Extract valid vendor names first, correctly handling names with spaces
xmlstarlet sel -t -m '//Class[Type="Vendor" and not(starts-with(Name, "Microsoft")) and not(Type="User")]' -v 'Name' -n $XML_FILE | while IFS= read -r VENDOR_NAME; do
    echo "Vendor Class: $VENDOR_NAME"
    xmlstarlet sel -t -m "//OptionDefinition[VendorClass='$VENDOR_NAME']" \
        -v 'concat("Option: ", Name, " - Default: ", DefaultValue, " - Description: ", Description)' -n $XML_FILE
done

echo -e "\nScope-Specific Option Values for Each Valid Vendor Class:"
echo "----------------------------------------------------------"
# Extract Scope IDs
SCOPE_IDS=$(xmlstarlet sel -t -m '//Scope' -v 'ScopeId' -n $XML_FILE)

for SCOPE_ID in $SCOPE_IDS; do
    # Extract and print option values if present
    OPTION_VALUES=$(xmlstarlet sel -t -m "//Scope[ScopeId='$SCOPE_ID']/OptionValues/OptionValue[VendorClass!='']" \
        -v 'concat("Option ID: ", OptionId, ", Value: ", Value, ", Vendor Class: ", VendorClass)' -n $XML_FILE)

    if [ ! -z "$OPTION_VALUES" ]; then
        echo "Scope ID: $SCOPE_ID"
        echo "$OPTION_VALUES"
    fi
done

echo -e "\\nDHCP Options Set in Scope Policies for All Vendor Classes:"
echo "----------------------------------------------------------------"

# Loop through each scope ID
xmlstarlet sel -t -m '//Scope' -v 'ScopeId' -n $XML_FILE | while read SCOPE_ID; do
    echo "Processing Scope ID: $SCOPE_ID"
    
    # Loop through policies within each scope, assuming a direct relationship for simplicity
    xmlstarlet sel -t \
      -m "//Scope[ScopeId='$SCOPE_ID']/Policies/Policy" \
      -v 'Name' -o ": " \
      -o $'\n' \
      -m 'OptionValues/OptionValue' \
      -v 'concat("Option ID: ", OptionId, ", Value: ", Value)' -n $XML_FILE

done

