#!/bin/sh

########################################################################
# Script pw_check.sh
########################################################################

function usage() {
  echo
  echo -e "\tUsage:          $0 <server-list>"
  echo -e "\t<server-list>:  file with list of BDDS"
  echo
  exit
}

SECONDS=0
debug=1
script=`basename $0`
scriptFolder=$(dirname $(readlink -f $0))
log="${scriptFolder}/${script%.sh}.log"
result_file="${scriptFolder}/password_test_results.txt"
> $log
> $result_file

function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then logPrefix="# DEBUG #"
  elif [ "$2" == "error" ]; then logPrefix="# ERROR #"; fi
  echo -e "$logPrefix $1" | tee -a $log
}

# Check if the server list file is provided
if [ $# -ne 1 ]; then
  usage
fi

server_list=$1

if [ ! -f "$server_list" ]; then
  echo "Server list file not found!"
  exit 1
fi

# Prompt user for three passwords
for ((i = 1; i <= 3; i++)); do
    read -rs -p "Enter password $i: " password
    printf "\n"
    PASSWORDS+=("$password")
done

while IFS= read -r server; do
  msg "Testing server: $server" "debug"
  # check port 22
  timeout 5 sh -c "</dev/tcp/${server}/22" > /dev/null 2>&1
  if [[ $? == 0 ]]; then
	  for idx in {0..2}; do
		password="${PASSWORDS[$idx]}"
		sshresult=$({ sleep 3; echo -e ${password}; } \
				  | /usr/bin/script -q /dev/null -c "ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -t root@${server} \"exit\"" \
				  | egrep "Permission denied")
		if [[ ${sshresult} = *"Permission denied"* ]]; then
		  echo "Server: $server | Password $((idx+1)): FAILED" >> $result_file
		  msg "Password $((idx+1)) failed for $server" "debug"
		else
		  echo "Server: $server | Password $((idx+1)): SUCCESS" >> $result_file
		  msg "Password $((idx+1)) worked for $server" "debug"
		fi
	  done
  else
       msg "Server ${server} not reachable" "error"
  fi
done < "$server_list"

duration=$SECONDS
msg "Password Testing took $(($duration / 60))min. & $(($duration % 60))sec." "debug"
msg "Results saved in $result_file" "debug"
