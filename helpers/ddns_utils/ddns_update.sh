#!/bin/sh
########################################################################
# Script DDNS_update.sh
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
folder="${scriptFolder}/nNC_update_${startTime}"
folder="${scriptFolder}/nNC_update_${startTime}"
input=$1
[[ -z "${input}" ]] && msg "input file missing" error && usage
[[ ! -e "${input}" ]] && msg "file ${input} doen't exist" error && usage
dnsServer="10.20.30.40"
# clean old reservoirs and build new one
oldNNC=(ls ${scriptFolder}/nNC_update_*)
[[ $oldNNC ]] && rm -rf ${scriptFolder}/nNC_update_* && msg "cleaned NNC directories" debug
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
# read and progress input file
rowsInputFile=$(wc -l < ${input})
if [ $rowsInputFile -eq 0 ]; then msg "no host(s) passed" error
else
  msg "${rowsInputFile} host(s) found in ${input}" debug
  inputCount=0
  IFS=$'\n'
  for line in $(cat "${input}"); do
      (( inputCount++ ))
      msg "working on A/PTR record ${inputCount} of ${rowsInputFile} (${line})"
      nsupdateFile="${folder}/nsupdate-${inputCount}.txt"
      echo "server ${dnsServer}" > ${nsupdateFile}
      echo >> ${nsupdateFile}
      # A record
      aRecord=`echo ${line} | awk -F, '{print $3}'`
      ipAddress=`echo ${line} | awk -F, '{print $1}'`
      echo "update add ${aRecord} 600 A ${ipAddress} " >> ${nsupdateFile}
      echo >> ${nsupdateFile}
      # PTR record
      ptrRecord=`echo ${line} | awk -F, '{print $1}' | awk -F. '{print $4"."$3"." $2"."$1}'`
      echo "update add ${ptrRecord}.in-addr.arpa 600 PTR ${aRecord}" >> ${nsupdateFile}
      echo >> ${nsupdateFile}
      echo "send" >> ${nsupdateFile}
      if [[ ! -e ${nsupdateFile} ]]; then
         msg "can't write file ${nsupdateFile} for nsupdate" error
      else
         nsupdate -v < ${nsupdateFile}
      fi
  done
  unset IFS
  msg "will sleep for 5 minutes now"
  sleep 300
  inputCount=0
  IFS=$'\n'
  for alias in $(cat "${input}"); do
      (( inputCount++ ))
      msg "working on CNAME record ${inputCount} of ${rowsInputFile} (${alias})"
      nsupdateAliasFile="${folder}/nsupdate-alias-${inputCount}.txt"
      echo "server ${dnsServer}" > ${nsupdateAliasFile}
      echo >> ${nsupdateAliasFile}
      # CNAME record
      aRecord=`echo ${alias} | awk -F, '{print $3}'`
      cnameRecord=`echo ${alias} | awk -F, '{print $2}'`
      echo "update delete ${cnameRecord} A" >> ${nsupdateAliasFile}
      echo >> ${nsupdateAliasFile}
      echo "update add ${cnameRecord} 600 CNAME ${aRecord}" >> ${nsupdateAliasFile}
      echo >> ${nsupdateAliasFile}
      echo "send" >> ${nsupdateAliasFile}
      if [[ ! -e ${nsupdateAliasFile} ]]; then
         msg "can't write file ${nsupdateAliasFile} for nsupdate" error
      else
         nsupdate -v < ${nsupdateAliasFile}
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
nncArchive="/tmp/nNC_update_${startTime}.tar.gz"
tar -C ${folder} -czPf ${nncArchive} .
if [[ ! -e $nncArchive ]]; then msg "can't create archive (${nncArchive})" error
else msg "archive of ${folder} created (${nncArchive})" debug; fi
# clean-up
cleaner ${folder}
for cleanUp in $(find /tmp -name "nNC_update_*.tar.gz" -type f -mtime +30 -delete -print); do msg "cleaned archive ${cleanUp}" debug; done
#EOF
