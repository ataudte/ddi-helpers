#!/bin/bash
########################################################################
# Script run_all_servers.sh - Run SSH/SCP on every server listed
########################################################################

usage() {
    echo "Usage: $0 [-r <ssh|scp>] [-l <server-list>] [-p <parameter>]"
    echo "    -r:  run SSH or SCP"
    echo "    -l:  file with list of servers"
    echo "    -p:  parameter for SSH/SCP (quoted for SSH or file for SCP)"
    exit 1
}

# Logging function
debug=0
script=$(basename "$0")
log="${script%.sh}.log"
: > "$log"

msg() {
    local message="$1"
    local level="${2:-info}"
    local timestamp
    timestamp=$(date '+%Y%m%d-%H%M%S')

    if [[ $debug -eq 1 || "$level" != "debug" ]]; then
        echo -e "$message"
    fi
    echo "[$timestamp] : $(echo "$level" | tr '[:lower:]' '[:upper:]') $message" >> "$log"
}

# Parse CLI arguments
while getopts ":r:l:p:" opt; do
    case "${opt}" in
        r)
            mode=${OPTARG}
            if [[ "$mode" != "ssh" && "$mode" != "scp" ]]; then
                usage
            fi
            msg "# $(echo "$mode" | tr '[:lower:]' '[:upper:]') in progress"
            ;;
        l)
            listfile=${OPTARG}
            [[ ! -f "$listfile" ]] && msg "# Oops! server list $listfile not found" && exit 1
            ;;
        p)
            param=${OPTARG}
            [[ "$mode" == "scp" && ! -f "$param" ]] && msg "# Oops! file $param not found for transfer" && exit 1
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND - 1))

[[ -z "$mode" || -z "$listfile" || -z "$param" ]] && usage

# Ask for username and password
read -p "# Enter $(echo "$mode" | tr '[:lower:]' '[:upper:]') username: " username
read -sp "# Enter password for $username: " password
echo " thanks"

# Clean list
cleaned_list="clean_${listfile}"
grep -v '^\s*$' "$listfile" | sort | uniq > "$cleaned_list"

[[ ! -s "$cleaned_list" ]] && msg "# Oops! no server(s) found in list" && exit 1
rows=$(wc -l < "$cleaned_list" | tr -d '[:space:]')
msg "# $rows server(s) found in $cleaned_list"

check_dns=0
max_parallel=2
count=0
running_jobs=0

while IFS= read -r server; do
    count=$((count + 1))
    msg "# Working on ${server} (${count} of ${rows})"

    if [[ "$check_dns" -eq 1 ]]; then
        if ! host "$server" >/dev/null 2>&1; then
            msg "# Oops! host ${server} not found"
            continue
        fi
    fi

    if nc -z -G 5 "$server" 22 >/dev/null 2>&1; then
        msg "# Port 22 on ${server} reachable"

        if [[ "$mode" == "ssh" ]]; then
            sshpass -p "$password" ssh -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 "${username}@${server}" "$param" < /dev/null | tee -a "$log" && msg "# SSH of ${param} to ${server} successful"

        elif [[ "$mode" == "scp" ]]; then
            (
                echo "# Starting SCP to ${server}"
                sshpass -p "$password" scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$param" "${username}@${server}:/tmp/" && msg "# SCP of ${param} to ${server}:/tmp successful"
            ) &
            running_jobs=$((running_jobs + 1))
            if (( running_jobs >= max_parallel )); then
                wait
                running_jobs=0
            fi
        fi
    else
        msg "# Oops! server ${server} not reachable"
    fi
done < "$cleaned_list"

if [[ "$mode" == "scp" ]]; then
    wait
fi