#!/bin/sh
########################################################################
# Script dependent_records.sh
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo "       Usage   : $0 <zone-list> <record-list>"
  echo " <zone-list>   : list of zones to transfer (with trailing dot)"
  echo "                 e.g. example.com."
  echo " <record-list> : list of dependent records (with trailing dot)"
  echo "                 e.g. host.example.com."
  echo
  exit
}
#
#######################################################################
# Function msg()
# print and log messages
#######################################################################
debug=0
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
# variables
args=2
if [ "$#" -lt "$args" ]; then usage; else zones=$1; records=$2; fi
if [[ ! -e $zones ]]; then msg "file $zones not found" error; exit; fi
if [[ ! -e $records ]]; then msg "file $records not found" error; exit; fi
#count lines
zrows=$(cat ${zones} | wc -l | sed 's/^ *//g')
if [ $zrows -eq 0 ]; then msg "no zone(s) passed" error; exit; else zcount=0; fi
# transfer zones
for zone in $(cat ${zones}); do
    (( zcount++ ))
	mname=$(dig ${zone} SOA +short | awk -F" " '{print $1}')
	if [[ ! $mname ]]; then msg "primary of ${zone} not found" error
	else 
       dig +noidnout +time=1 +tries=1 +noedns @${mname} ${zone} axfr > "db.${zone}"
       if grep -q "SOA" "db.${zone}"; then msg "transfer of ${zone} from ${mname} done ($zcount of $zrows)";
       else msg "transfer of ${zone} from ${mname} failed ($zcount of $zrows)" error; cleaner "db.${zone}"; fi
	fi
done # zones
# count zones
zfiles=zone-files.txt
ls -l db.* 2>/dev/null | awk -F" " '{print $9}' > $zfiles
if [[ ! -e $zfiles ]]; then msg "file ${zfiles} not found" error; exit; fi
frows=$(cat $zfiles | wc -l | sed 's/^ *//g')
if [ $frows -eq 0 ]; then msg "no zone file(s) passed" error; exit; else fcount=0; fi
# process zone files
for file in $(cat ${zfiles}); do
    (( fcount++ ))
    drecords="dependencies_${file#db.}txt"
    awk 'FNR==NR{a[$NF]=tolower($0);next}{ if(a[tolower($1)]){print $0 " : " a[tolower($1)]}}' $file $records > $drecords
    if [[ ! -e $drecords ]]; then msg "no dependencies found in zone ${file#db.} ($fcount of $frows)"
    else msg "dependencies of zone ${file#db.} stored in ${drecords} ($fcount of $frows)"; fi
    cleaner $file
done # files
cleaner $zfiles
exit
#EOF
