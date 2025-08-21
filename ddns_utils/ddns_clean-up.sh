#!/bin/sh
########################################################################
# Script DDNS_clean-up.sh
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo "   "
  echo "   Usage: $0 input.txt"
  echo "   input: ip,alias,host"
  echo "   "
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
SECONDS=0
startTime=$(date '+%Y%m%d-%H%M%S')
folder="${scriptFolder}/nNC_clean-up_${startTime}"
input=$1
[[ -z "${input}" ]] && msg "input file missing" error && usage
[[ ! -e "${input}" ]] && msg "file ${input} doen't exist" error && usage
dnsServer="10.20.30.40"
dnsZone="zone.de"
dnsZoneFile="${folder}/${dnsZone}.db"
dnsCanonisedFile="${dnsZoneFile}.canonised"
dnsHostFile="${dnsZoneFile}.hosts"
inputIpFile="${folder}/${input}.ips"
# clean old reservoirs and build new one
oldNNC=(ls ${scriptFolder}/nNC_clean-up_*)
[[ $oldNNC ]] && rm -rf ${scriptFolder}/nNC_clean-up_* && msg "cleaned NNC directories" debug
mkdir $folder
if [[ ! -e $folder ]]; then msg "can't build reservoir (${folder})" error; exit; fi
msg "details logged in ${log}" debug
# save daemon.log
daemonLog="${folder}/${script%.sh}_daemon.log"
tail -f /var/log/daemon.log > ${daemonLog} &
trap "pkill -P $$" EXIT 2>&1 >/dev/null &
sleep 2
if [[ ! -e $daemonLog ]]; then msg "can't save daemon.log (${daemonLog})" error
else msg "daemon.log saved (${daemonLog})" debug; fi
# get zone file
dig @${dnsServer} ${dnsZone} axfr -b 127.0.0.2 > ${dnsZoneFile}
if [[ ! -e ${dnsZoneFile} ]]; then msg "zone transfer of ${dnsZone} from ${dnsServer} failed" error; exit; fi
# canonicalization of zone file
named-checkzone -D -o ${dnsCanonisedFile} ${dnsZone} ${dnsZoneFile} &>/dev/null
if [[ ! -e ${dnsCanonisedFile} ]]; then msg "canonicalization of ${dnsZone} failed" error; exit; fi
msg "zone file of ${dnsZone} canonised and stored in ${folder}" debug
# build IP list
awk -F"," '{print $1}' ${input} | sed 's/\./\\./g' > ${inputIpFile}
if [[ ! -e ${inputIpFile} ]]; then msg "reading IPs from ${input} failed" error; exit; fi
msg "list of IPs from ${input} stored in ${folder}" debug
# build host list
egrep -f ${inputIpFile} ${dnsCanonisedFile} > ${dnsHostFile}
if [[ ! -e ${dnsHostFile} ]]; then msg "grep from ${dnsCanonisedFile} with ${inputIpFile} failed" error; exit; fi
msg "list of hosts from ${dnsZone} stored in ${folder}" debug
# read and progress host file
rowsHostFile=$(wc -l < ${dnsHostFile})
if [ $rowsHostFile -eq 0 ]; then msg "no host(s) passed" error
else
  msg "${rowsHostFile} host(s) found in ${dnsHostFile}" debug
  hostCount=0
  IFS=$'\n'
  for host in $(cat "${dnsHostFile}"); do
      (( hostCount++ ))
      msg "working on ${hostCount} of ${rowsHostFile} (${host%%.*})"
      nsupdateHostFile="${dnsZoneFile}_nsupdate_${hostCount}.txt"
      echo "server ${dnsServer}" > ${nsupdateHostFile}
      echo "update delete ${host}" >> ${nsupdateHostFile}
      echo "send" >> ${nsupdateHostFile}
      if [[ ! -e ${nsupdateHostFile} ]]; then
         msg "can't write file ${nsupdateHostFile} for nsupdate" error
      else
         nsupdate -v < ${nsupdateHostFile}
      fi
  done
  unset IFS
fi
# read and progress IP file
rowsinputIpFile=$(wc -l < ${inputIpFile})
if [ $rowsinputIpFile -eq 0 ]; then msg "no IP(s) passed" error
else
  msg "${rowsinputIpFile} IP(s) found in ${inputIpFile}" debug
  ipCount=0
  IFS=$'\n'
  for ip in $(cat "${inputIpFile}"); do
      (( ipCount++ ))
      tmpIp=${ip//\\/}
      msg "working on ${ipCount} of ${rowsinputIpFile} (${tmpIp})"
      ptrRecord=`echo ${tmpIp} | awk -F. '{print $4"."$3"." $2"."$1}'`
      nsupdateIpFile="${inputIpFile}.${ip//\\\./-}.nsupdate"
      echo "server ${dnsServer}" > ${nsupdateIpFile}
      echo "update delete ${ptrRecord}.in-addr.arpa" >> ${nsupdateIpFile}
      echo "send" >> ${nsupdateIpFile}
      if [[ ! -e ${nsupdateIpFile} ]]; then
         msg "can't write file ${nsupdateIpFile} for nsupdate" error
      else
         nsupdate -v < ${nsupdateIpFile}
      fi
  done
  unset IFS
fi
# results
duration=$SECONDS
msg "process took $(($duration / 60)) minutes and $(($duration % 60)) seconds" debug
bundle=$(ls ${folder} | wc -l)
msg "${bundle} files in reservoir (${folder})" debug
# archiving
nncArchive="/tmp/nNC_clean-up_${startTime}.tar.gz"
tar -C ${folder} -czPf ${nncArchive} .
if [[ ! -e $nncArchive ]]; then msg "can't create archive (${nncArchive})" error
else msg "archive of ${folder} created (${nncArchive})" debug; fi
# clean-up
cleaner ${folder}
for cleanUp in $(find /tmp -name "nNC_clean-up_*.tar.gz" -type f -mtime +30 -delete -print); do msg "cleaned archive ${cleanUp}" debug; done
#EOF
