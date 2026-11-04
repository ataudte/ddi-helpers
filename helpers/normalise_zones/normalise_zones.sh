#!/bin/sh
########################################################################
# Script normalise-zones.sh
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
    echo " "
    echo "               Usage: $0 <named-directory> <named.conf>"
    echo "   <named-directory>: name of directory with config & zone files"
    echo "        <named.conf>: name of config file"
    echo "                      expected format:"
    echo "                      zone \"<zone-name>\" { type master; file \"<file-name>\"; };"
    echo "                      <zone-name> equals <file-name>"
    echo " "
    echo "       Prerequisites: - named-checkzone (bind-utils)"
    echo "                      - awk, egrep, grep, sed"
    echo " "
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
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then logPrefix="# DEBUG #"
  elif [ "$2" == "error" ]; then logPrefix="# ERROR #"; fi
  # build message
  if [ $debug -eq 1 ] && [ "$2" == "debug" ]; then
     echo "${logPrefix} $1"
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  elif [ $debug -eq 0 ] && [ "$2" == "debug" ]; then
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  else
     echo "${logPrefix} $1"
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  fi
}
#
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
# Function cleanms()
# delete timestamps from dynamic MS-DNS zones
#######################################################################
function cleanms() {
  msfile="$*"
  if egrep -q "\[Aging:[0-9]{7}\]*" "${msfile}"; then
    msg "clean-up of MS-DNS timestamps in zone file ${msfile}" debug
    sed -E "s/\[Aging:[0-9]{7}\]*//" "${msfile}" > "${msfile}.tmp" && mv "${msfile}.tmp" "${msfile}"
  fi
}
#
#######################################################################
# Function canzonefile()
# canonicalization of zone files
#######################################################################
function canzonefile() {
  suffix="$1"
  zfile="$2"
  zname="$3"
  canfile="${zfile}_${suffix}"
  named-checkzone -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  if [[ ! -f "${canfile}" ]] ; then
     msg "canonicalization of zone ${zname} failed" error
     exit
  else
     msg "canonicalization of zone ${zname} done (${canfile})" debug
  fi
}
#
#######################################################################
# Main program
#######################################################################
# get and validate parameters
args=2
if [ "$#" -lt "$args" ]; then usage; else directory=$1; config=$2; fi
if [[ ! -d "$directory" ]] ; then msg "directory ${directory} not found" error; exit; fi
if [[ ! -f "$directory/$config" ]] ; then msg "config file ${config} not found" error; exit; fi
# debug
[[ ! -z $debug ]] && msg "debug mode enabled" debug
# validate prerequisites
msg "validation of prerequisites"
declare -a prereq=("named-checkzone" "egrep" "awk" "sed")
for program in "${prereq[@]}"
do
  if ! [ -x "$(command -v $program)" ]; then
     [[ ! -z $debug ]] && msg "prerequisite ${program} not found" error
     exit
  else
     [[ ! -z $debug ]] && msg "validation of prerequisite ${program} done" debug
  fi
done
# collect zone files
msg "collecting zone files"
reversefile="reverse_zones.txt"
forwardfile="forward_zones.txt"
egrep -i "master\;" "${directory}/${config}" | egrep -i "arpa" | awk -F" " '{print $2}' > ${reversefile}
sed -i -e 's/\"//g' ${reversefile}
if [[ ! -f "$reversefile" ]] ; then msg "can't create reverse file (${reversefile})" error; exit; fi
egrep -i "master\;" "${directory}/${config}" | egrep -i -v "arpa" | awk -F" " '{print $2}' > ${forwardfile}
sed -i -e 's/\"//g' ${forwardfile}
if [[ ! -f "$forwardfile" ]] ; then msg "can't create forward file (${forwardfile})" error; exit; fi
rrows=$(cat $reversefile | wc -l | awk '{$1=$1};1')
if [ $rrows -eq 0 ]; then msg "no reverse zones found" error; exit; fi
frows=$(cat $forwardfile | wc -l | awk '{$1=$1};1')
if [ $frows -eq 0 ]; then msg "no forward zones found" error; exit; fi
# validate content of zone files
msg "validation of zone content"
for vzone in `cat $reversefile $forwardfile`; do cleanms "${directory}/${vzone}"; done
# canonicalization of zone files
msg "canonicalization of zone files"
for czone in `cat $reversefile $forwardfile`; do canzonefile "canonised" "${directory}/${czone}" ${czone}; done
# process forward zones
msg "processing forward zones"
forwardrecords="forward_records.txt"
#cleaner $forwardrecords
for fzone in `cat $forwardfile`; do
    egrep "[0-9]+[[:space:]]IN[[:space:]]A[[:space:]]" "${directory}/${fzone}_canonised" >> ${forwardrecords}
done
if [[ ! -f "$forwardrecords" ]] ; then msg "can't process forward records (${forwardrecords})" error; exit; fi
arows=$(cat $forwardrecords | wc -l | awk '{$1=$1};1')
if [ $arows -eq 0 ]; then msg "no forward records found" error; exit; fi
# clean-up
msg "cleaning up"
cleaner "${forwardrecords}"
cleaner "${reverserecords}"
cleaner "${forwardfile}*"
cleaner "${reversefile}*"
#cleaner "${directory}/*_canonised"
#EOF
