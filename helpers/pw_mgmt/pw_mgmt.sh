#!/bin/sh
########################################################################
# Script pw_mgmt.sh
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo -e "\tUsage:          $0 <server-list>"
  echo -e "\t<server-list>:  file with list of BDDS"
  echo
  exit
}
#
#######################################################################
# Function msg()
# print and log messages
#######################################################################
debug=1
script=`basename $0`
scriptFolder=$(dirname $(readlink -f $0))
log="${scriptFolder}/${script%.sh}.log"
> $log
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then logPrefix="# DEBUG #"
  elif [ "$2" == "error" ]; then logPrefix="# ERROR #"; fi
  # build message
  if [ $debug -eq 1 ] && [ "$2" == "debug" ]; then
     echo -e "${logPrefix} $1"
	 echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  elif [ $debug -eq 0 ] && [ "$2" == "debug" ]; then
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  else
     echo -e "${logPrefix} $1"
	 echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  fi
}
#
#######################################################################
# Function testssh()
# validate ssh credentials
#######################################################################
function testssh() {
  local server=$1
  local login=$2
  local password=$3
  local sshresult
  sshresult=$({ sleep 3; echo -e ${password}; } \
              | /usr/bin/script -q /dev/null -c "ssh -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -t ${login}@${server} \"exit\"" \
			  | egrep "Permission denied")
  if [[ ${sshresult} = *"Permission denied"* ]]; then
     msg "validation of credentials failed" error
	 return 1
  else
     msg "validation of credentials successful" debug
	 return 0
  fi
}
#
#######################################################################
# Main program
#######################################################################
# check list of servers
args=1
if [ "$#" -lt "$args" ]; then usage; else file=$1; fi
if [[ ! -e $file ]]; then msg "file $file doesn't exist" error; exit; fi
bddslist="clean_"$file
sed '/^\s*$/d' $file  | sort | uniq > $bddslist
if [[ ! -e $bddslist ]]
then
  msg "can't access cleaned list ($bddslist)" error
  exit
else
  msg "file $file cleaned ($bddslist)" debug
fi
rows=$(cat $bddslist | wc -l)
if [ $rows -eq 0 ]
then
  msg "no server(s) passed" error
  exit
else
  msg "$rows server(s) found in $bddslist"
  count=0
fi
# get user and passwords from input
echo -n "# ----- # enter root password:        " && read -es bddsrootpwd && echo "thanks"
echo -n "# ----- # enter user account:         " && read -e bddsuser
echo -n "# ----- # enter user's new password:  " && read -es bddsnewpwd && echo "thanks"
echo -n "# ----- # repeat user's new password: " && read -es bddsnewpwd2 && echo "thanks"
if [[ "${bddsnewpwd}" = "${bddsnewpwd2}" ]]; then
   msg "passwords match" debug
else
   msg "termination by password mismatch" error
   exit
fi
# read and progress file
for bdds in $(cat "$bddslist"); do
    (( count++ ))
    msg "working on ${bdds} ($count of $rows)"
    # check BDDS in DNS
    checkdns="false"
    if [[ true == "$checkdns" ]]; then
       if ! host ${bdds} | grep -q address; then
          msg "host ${bdds} not found" error
          continue
       fi
    fi
    # check port 22
    timeout 10 sh -c "</dev/tcp/${bdds}/22" > /dev/null 2>&1
    if [[ $? == 0 ]]; then
       msg "port 22 on server ${bdds} reachable" debug
       # login and run
       msg "working on server ${bdds}"
	   msg "validating root access for ${bdds}" debug
	   testssh ${bdds} root ${bddsrootpwd}
	   if [[ $? -ne 0 ]]; then continue; fi
       { sleep 3; echo -e ${bddsrootpwd}; } | /usr/bin/script -q /dev/null -c "ssh -q -o StrictHostKeyChecking=no -t root@${bdds} \"yes ${bddsnewpwd} | passwd -q ${bddsuser}\"" | tee -a $log
	   if [[ "${bddsuser}" = "root" ]]; then
	      msg "validating new root credentials for ${bdds}" debug
	      testssh ${bdds} ${bddsuser} ${bddsnewpwd}
	      if [[ $? -ne 0 ]]; then continue; fi
	   fi
	   msg "done with ${bdds}"
    else
       msg "server ${bdds} not reachable" error
    fi
done
#EOF
