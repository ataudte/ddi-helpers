#!/bin/sh
########################################################################
# Script check-dhcp-fo.sh
########################################################################
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
#######################################################################
# Function cleaner()
# delete file and check
#######################################################################
function cleaner() {
  fileToBeDeleted=$1
  rm -rf ${fileToBeDeleted}
  [[ ! -e "${fileToBeDeleted}" ]] && msg "deleted ${fileToBeDeleted}" debug
}
#######################################################################
# Main program
#######################################################################
dhcpd="/replicated/etc/dhcpd.conf"
if [[ ! -e $dhcpd ]]; then msg "file $dhcpd doesn't exist" error; exit; fi
secret=$(awk 'c&&!--c;/^key adoniskey/{c=3}' ${dhcpd} | awk -F"\"" '{print $2}')
if [[ -z "$secret" ]]; then msg "could't extract secret" error; exit; fi
association=$(awk '/^failover peer/' ${dhcpd} | awk -F"\"" '{print $2}')
if [[ -z "$association" ]]; then msg "could't extract association" error; exit; fi
msg "config:        $dhcpd" debug
msg "secret:        ${secret:0:10}..." debug
msg "peers:         $association" debug
omapicmd="${scriptFolder}/${script%.sh}.cmd"
echo "server localhost" > ${omapicmd}
echo "port 7911" >> ${omapicmd}
echo "key adoniskey ${secret}" >> ${omapicmd}
echo "connect" >> ${omapicmd}
echo "new failover-state" >> ${omapicmd}
echo "set name = \"${association}\"" >> ${omapicmd}
echo "open" >> ${omapicmd}
if [[ ! -e $omapicmd ]]; then msg "file $omapicmd doesn't exist" error; exit; fi
lstate=$( omshell < $omapicmd | awk '/^local-state/' | awk -F":" '{print $4}')
if [[ -z "$lstate" ]]; then msg "could't extract local-state" error; exit; fi
pstate=$( omshell < $omapicmd | awk '/^partner-state/' | awk -F":" '{print $4}')
if [[ -z "$pstate" ]]; then msg "could't extract partner-state" error; exit; fi
declare -A states
states[01]="startup"
states[02]="normal"
states[03]="communications interrupted"
states[04]="partner down"
states[05]="potential conflict"
states[06]="recover"
states[07]="paused"
states[08]="shutdown"
states[09]="recover done"
states[10]="resolution interrupted"
states[11]="conflict done"
states[254]="recover wait"
msg "local-state:   ${states[$lstate]}"
msg "partner-state: ${states[$pstate]}"
cleaner ${omapicmd}
