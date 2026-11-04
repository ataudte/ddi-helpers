#!/bin/sh
########################################################################
# Script dns-review-bdds.sh
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
    echo " "
    echo "       Prerequisites: - named-checkconf (bind-utils)"
    echo "                      - named-checkzone (bind-utils)"
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
# set colors
colorRed='\033[0;97m\033[41m'
colorGreen='\033[0;97m\033[42m'
colorYellow='\033[0;97m\033[43m'
colorBlue='\033[0;97m\033[44m'
colorWhite='\033[0;30m\033[47m'
colorOff='\033[0m'
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"; cliPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then
       logPrefix="# DEBUG #"
       cliPrefix="# ${colorBlue}DEBUG${colorOff} #"
  elif [ "$2" == "error" ]; then
       logPrefix="# ERROR #"
       cliPrefix="# ${colorRed}ERROR${colorOff} #"; fi
  # build message
  if [ $debug -eq 1 ] && [ "$2" == "debug" ]; then
     echo "${cliPrefix} $1"
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  elif [ $debug -eq 0 ] && [ "$2" == "debug" ]; then
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  else
     echo "${cliPrefix} $1"
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
  if egrep -q "\[A.*:[0-9]{7}\]*" "${msfile}"; then
    msg "clean-up of MS-DNS timestamps in zone file ${msfile##*/}" debug
    sed -E "s/\[A.*:[0-9]{7}\]*//" "${msfile}" > "${msfile}.tmp" \
        && cp ${msfile} "${msfile}_$(date '+%Y%m%d-%H%M%S').save" \
        && mv "${msfile}.tmp" ${msfile}
  fi
}
#
#######################################################################
# Function canzonefile()
# canonicalization of zone files
#######################################################################
function canzonefile() {
  suffix="$1"; zfile="$2"; zname="$3"
  canfile="${zfile}_${suffix}"
  istext=""; israw=""
  istext=$( named-checkzone -f text ${zname} ${zfile} | tail -1 )
  israw=$( named-checkzone -f raw ${zname} ${zfile} | tail -1 )
  if [ "$istext" == "OK" ]; then named-checkzone -f text -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  elif [ "$israw" == "OK" ]; then named-checkzone -f raw -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  else msg "formating zone ${zname} failed" error; fi
  if [[ ! -f "${canfile}" ]] ; then msg "canonicalizing zone ${zname} failed" error; fi
}
#
#######################################################################
# Function zonecollect()
# generate list of zone type
#######################################################################
function zonecollect () {
  ztype=$1
  zlist=$2
  zconf=$3
  zraw="${zlist%.txt}.raw"
  egrep -i "type ${ztype}" "${zconf}" | awk -F" " '{print $2}' | sed 's/\"//g' > ${zlist}
  if [[ ! -f "$zlist" ]] ; then msg "can't create ${ztype} file (${zlist})" debug; fi
  rows=$(cat $zlist | wc -l | awk '{$1=$1};1')
  if [ $rows -eq 0 ]; then msg "no ${ztype} zones found in ${zconf}" debug
  else egrep -i "type ${ztype}" "${zconf}" > ${zraw}; fi
  return $rows
}
#
#######################################################################
# Main program
#######################################################################
# get and validate parameters
args=2
if [ "$#" -lt "$args" ]; then usage; else nfolder=$1; nconf=$2; fi
if [[ ! -d "$nfolder" ]] ; then msg "directory ${nfolder} not found" error; exit; fi
if [[ ! -f "$nfolder/$nconf" ]] ; then msg "config file ${nconf} not found" error; exit; fi
# process reverse zones
arpa=1
# debug
[[ ! -z $debug ]] && msg "debug mode enabled" debug
# validate prerequisites
msg "validation of prerequisites"
declare -a prereq=("named-checkconf" "named-checkzone" "egrep" "awk" "sed")
for program in "${prereq[@]}"; do
  if ! [ -x "$(command -v $program)" ]; then [[ ! -z $debug ]] && msg "prerequisite ${program} not found" error; exit
  else [[ ! -z $debug ]] && msg "validation of prerequisite ${program} done" debug; fi
done
#
# jump to conf folder
cd ${nfolder}
# flatten config file
msg "flattening config file ( ${nconf} )"
flatnconf="${nconf%.*}_flat.conf"
cat ${nconf} | sed 's/^[[:blank:]]*//' \
             | tr -d '\n' | tr -s '' \
             | sed 's/;include /\ninclude /g' \
             | sed 's/;options /\noptions /g' \
             | sed 's/;view /\nview /g' \
             | sed 's/;zone /\nzone /g' \
             | sed 's/;acl /\nacl /g' \
             | sed 's/qddns.*$/\} /g' \
             | sed 's/zone "[^"]*" policy .*//g' \
             | sed 's/$/\;/g' \
             | sed 's/\;\;/\;/g' \
             | egrep "^include|^options|^zone|^acl" \
             | egrep -v -i "type 127\.in-addr|0\.ip6" \
             > ${flatnconf}
if [[ ! -f "$flatnconf" ]] ; then msg "can not flatten config file ( ${flatnconf} )" error; exit; fi
# forwarding
msg "▓▓ WORKING ON FORWARDING ▓▓"
gfpolicy=$(egrep "^options" ${flatnconf} \
           | awk -v RS="forward " -v FS=";" 'NR>1{print $1}' \
           | sed 's/[[:space:]]//g' \
           | sed 's/\;$/ /g' \
           | sed 's/\;/ \& /g')
gfaddress=$(egrep "^options" ${flatnconf} \
            | awk -v RS="forwarders {" -v FS="}" 'NR>1{print $1}' \
            | sed 's/[[:space:]]//g' \
            | sed 's/\;$/ /g' \
            | sed 's/\;/ \& /g')
msg "// Policy: ${gfpolicy}"
msg "// Forwarders: ${gfaddress}"
# normalise named.conf
msg "normalizing config file ( ${flatnconf} )"
normnconf="${nconf%.*}_norm.conf"
checkconf=$((named-checkconf -p ${flatnconf}) 2>&1) || { msg "${flatnconf} not valid ( ${checkconf} )" error; exit; }
named-checkconf -p ${flatnconf} | tr -d '\n' | tr -s '' \
                                | sed 's/[[:space:]]/ /g' \
                                | sed 's/;zone /\nzone /g' \
                                | sed 's/;acl /\nacl /g' \
                                | sed 's/$/\;/g' \
                                | sed 's/\;\;/\;/g' \
                                | egrep "^zone|^acl" \
                                > ${normnconf}
if [[ ! -f "$normnconf" ]] ; then msg "can not normalize config file ( ${normnconf} )" error; exit; fi
# collect zone files
msg "collecting zone files"
hintfile="hint_zones.txt"
masterfile="master_zones.txt"
slavefile="slave_zones.txt"
forwardfile="forward_zones.txt"
zonecollect "hint" $hintfile $normnconf; hrows=$?
zonecollect "master" $masterfile $normnconf; mrows=$?
zonecollect "slave" $slavefile $normnconf; srows=$?
zonecollect "forward|stub" $forwardfile $normnconf; frows=$?
if [[ $mrows -eq 0 && $srows -eq 0 && $frows -eq 0 ]]; then msg "noting to do"; exit; fi
if [ $arpa -eq 0 ]; then sed -i -e '/\.arpa/d' *.txt; msg "reverse zones ignored" debug; fi
# root hints
if [ $mrows -eq 0 ]; then msg "no root hints found"
else
   msg "▓▓ WORKING ON ROOT HINTS ▓▓"
   hfile=$(awk -v RS="file \"" -v FS="\"" 'NR>1{print $1}' "${hintfile%.txt}.raw" \
          | sed 's/[[:space:]]//g' \
          | sed 's/\;$/ /g' \
          | sed 's/\;/ \& /g')
   if [[ ! -f "$hfile" ]] ; then msg "zone file ${hfile} not found" error;
   else
      msg "// root hints in ${hfile}"
      declare -a rrhints=( $(egrep "[[:space:]]A[[:space:]]|[[:space:]]AAAA[[:space:]]" ${hfile} | awk '{print $1 "(" $NF ")"}') )
      for rrhint in ${rrhints[@]}; do msg "   ${rrhint}"; done
   fi
fi
# primary zones
if [ $mrows -eq 0 ]; then msg "no primary zones found"
else
   msg "▓▓ WORKING ON PRIMARY ZONES ▓▓"
   for mzone in `cat $masterfile`; do
       zfile=$(grep "zone \"${mzone}\"" "${masterfile%.txt}.raw" \
               | awk -v RS="file \"" -v FS="\"" 'NR>1{print $1}' \
               | sed 's/[[:space:]]//g' \
               | sed 's/\;$/ /g' \
               | sed 's/\;/ \& /g')
       if [[ ! -f "$zfile" ]] ; then msg "zone file ${zfile} not found" error; continue; fi
       # canonicalization of zone files
       msg "normalizing primary zones" debug
       cleanms ${zfile}
       canzonefile "canonised" ${zfile} ${mzone}
       msg "// record types of ${mzone}"
       declare -a rrtypes=( $(awk -F" " '{print $4}' "${zfile}_canonised" | sort | uniq) )
       for rrtype in ${rrtypes[@]}; do
           rrcount=$(egrep "[[:space:]]${rrtype}[[:space:]]" "${zfile}_canonised" | wc -l | awk '{$1=$1};1')
           msg "   ${mzone}\t${rrcount} ${rrtype} records"
       done # record types
       msg "// delegations of ${mzone}"
       IFS=$'\n'
       for delegation in $(egrep "[[:space:]]NS[[:space:]]" "${zfile}_canonised"); do
           msg "   $(echo ${delegation} | awk -F" " '{print $1 " delegated to " $5}')"
       done # delegations
       unset IFS
   done # zone file
fi
# slave zones
if [ $srows -eq 0 ]; then msg "no secondary zones found"
else
   msg "▓▓ WORKING ON SECONDARY ZONES ▓▓"
   for szone in `cat $slavefile`; do
     msg "// primary server(s) of ${szone}"
     masters=$(grep "zone \"${szone}\"" "${slavefile%.txt}.raw" \
               | awk -v RS="masters {" -v FS="}" 'NR>1{print $1}' \
               | sed 's/[[:space:]]//g' \
               | sed 's/\;$/ /g' \
               | sed 's/\;/ \& /g')
     msg "   ${szone} transfered from ${masters}"
   done # secondary zones
fi
# forward zones
if [ $frows -eq 0 ]; then msg "no forward zones found"
else
   msg "▓▓ WORKING ON FORWARD ZONES ▓▓"
   for fzone in `cat $forwardfile`; do
     msg "// forwarder(s) of ${fzone}"
     forwarders=$(grep "zone \"${fzone}\"" "${forwardfile%.txt}.raw" \
               | awk -v RS="masters {|forwarders {" -v FS="}" 'NR>1{print $1}' \
               | sed 's/[[:space:]]//g' \
               | sed 's/\;$/ /g' \
               | sed 's/\;/ \& /g')
     msg "   ${fzone} forwarded to ${forwarders}"
   done # secondary zones
fi
# clean-up
msg "cleaning up"
cleaner ${flatnconf}
cleaner ${normnconf}
cleaner "*_zones.txt*"
cleaner "*_zones.raw*"
cleaner "*_canonised*"
#EOF
