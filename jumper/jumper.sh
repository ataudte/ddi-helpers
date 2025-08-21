#!/bin/sh
########################################################################
# run SSH to server picked from list
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo -e "Usage:  $0 <server-list>"
  echo -e "format: name,role,address"
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
log="${scriptFolder}/${script%.sh}_$(date '+%Y%m%d-%H%M%S').log"
> $log
# set colors
colorRed='\033[1;97m\033[41m'
colorGreen='\033[1;97m\033[42m'
colorYellow='\033[1;97m\033[43m'
colorBlue='\033[1;97m\033[44m'
colorWhite='\033[0;30m\033[47m'
colorOff='\033[0m'
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then logPrefix="# ${colorBlue}DEBUG${colorOff} #"
  elif [ "$2" == "error" ]; then logPrefix="# ${colorRed}ERROR${colorOff} #"; fi
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
#######################################################################
# Function cleaner()
# delete file and check
#######################################################################
function cleaner() {
  fileToBeDeleted=$1
  rm -rf ${fileToBeDeleted}
  [[ ! -e "${fileToBeDeleted}" ]] && msg "deleted ${fileToBeDeleted}" debug
}
#
#######################################################################
# Main program
#######################################################################
# check list of servers
args=1
if [ "$#" -lt "$args" ]; then usage; else file=$1; fi
if [[ ! -e $file ]]; then msg "file $file doesn't exist" error; exit; fi
srvlist="${file%.txt}_clean.txt"
sed '/^\s*$/d' $file  | sort | uniq > $srvlist
if [[ ! -e $srvlist ]]
then
  msg "can't access cleaned list ($srvlist)" error; exit
else
  msg "${RED}file $file cleaned ($srvlist)${NC}" debug
fi
rows=$(cat $srvlist | wc -l | awk '{$1=$1};1')
if [ $rows -eq 0 ]
then
  msg "no server(s) passed" error; exit
else
  msg "$rows server(s) found in $srvlist" debug
fi
# create list for user
T=`tput cols`
COLUMNS=$T
IFS=$'\n'
PS3=$'\033[1;97m\033[41m pick server to connect:\033[0m '
select line in `cat ${srvlist}`; do
      pick=$REPLY
      if (($pick >= 1 && $pick <= $rows)); then
         hostname=$(echo ${line} | cut -d, -f1)
         role=$(echo ${line} | cut -d, -f2)
         address=$(echo ${line} | cut -d, -f3)
         timeout 5 sh -c "</dev/tcp/${address}/22" > /dev/null 2>&1
         if [[ $? == 0 ]]; then
            msg "port 22 on server ${hostname} reachable" debug
            # login
            ssh -q -o StrictHostKeyChecking=no -t root@${address} | tee -a $log
         else
            msg "server ${hostname} not reachable at ${address}" error
         fi # if SSH ok
      else
         msg "cancellation because selection not included"
      fi # if pick in range
      break
done
unset IFS
# clean-up
cleaner ${srvlist}
for cleanlog in $(find $scriptFolder -name "${script%.sh}_*.log" -type f -mtime +7 -delete -print); do
    msg "cleaned log ${cleanlog##*/}" debug;
done
#EOF
