#!/bin/bash

function delete_file() {
    # The function takes one argument: the file path
    local file_path="$1"

    # Check if the file exists
    if [[ -f "$file_path" ]]; then
        echo "## deleting $file_path"
        rm "$file_path"
    fi
}

# Check if the script is running as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Output file paths
PCAP_FILE="dns_capture.pcap"
LOG_FILE="tcpdump_log.txt"

delete_file $PCAP_FILE
delete_file $LOG_FILE

# Check if at least one argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 [dig command options]"
    exit 1
fi

# Prompt user for DNS server IP
read -p "## DNS server IP (IPv4 or IPv6): " dns_server

# Validate the DNS server IP
if ! [[ $dns_server =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ || $dns_server =~ ^([0-9a-fA-F:]+)$ ]]; then
    echo "Invalid IP format. Exiting."
    exit 1
fi

# Construct dig command with user input
dig_command="dig @${dns_server} $*"
echo "## dig @${dns_server} $*"


# Run tcpdump in the background, output to both file and screen
tcpdump -i any "port 53 and (udp or tcp) and host $dns_server" -w $PCAP_FILE -vv > $LOG_FILE 2>&1 &
TCPDUMP_PID=$!
sleep 5

# Run the dig command
$dig_command
sleep 5

# Stop tcpdump after the command completes
kill $TCPDUMP_PID
wait $TCPDUMP_PID

# Validate if the files were created
if [ ! -f "$PCAP_FILE" ]; then
    echo "Error: Failed to create $PCAP_FILE."
    exit 1
fi

echo "DNS capture saved to $PCAP_FILE"
echo "Check $LOG_FILE for tcpdump output."

if ! command -v wireshark &> /dev/null; then
    echo "Wireshark is not installed."
    exit 1
else
    wireshark -r $PCAP_FILE
fi
