#!/bin/sh
########################################################################
# check multiple ports for each server in list
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo -e "Usage:  $0 <server-list>"
  echo -e "format: fqdn or address of server(s)"
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
  msg "file $file cleaned ($srvlist)" debug
fi
rows=$(cat $srvlist | wc -l | awk '{$1=$1};1')
if [ $rows -eq 0 ]
then
  msg "no server(s) passed" error; exit
else
  msg "$rows server(s) found in $srvlist" debug; count=0
fi
# ports to validate
declare -a ports=("22/tcp" "53/udp" "53/tcp" "67/udp" "69/udp" "123/udp" "161/udp" "547/udp" "647/udp" "847/udp" "10042/tcp" "12345/tcp")
msg "ports: ${ports[*]}" debug
for srv in $(cat "$srvlist"); do
  (( count++ ))
  for port in "${ports[@]}"; do
      timeout 5 sh -c "</dev/${port##*/}/${srv}/${port%%/*}" > /dev/null 2>&1
      if [[ $? == 0 ]]; then
	     msg " ${colorGreen}OK${colorOff} port ${port} on ${srv} ($count of $rows)"
	  else
	     msg "${colorRed}NOK${colorOff} port ${port} on ${srv} ($count of $rows)" error; fi
  done # ports
done # servers
count=0
# clean-up
cleaner ${srvlist}
for cleanlog in $(find $scriptFolder -name "${script%.sh}_*.log" -type f -mtime +7 -delete -print); do
    msg "cleaned log ${cleanlog##*/}" debug;
done
#EOF
