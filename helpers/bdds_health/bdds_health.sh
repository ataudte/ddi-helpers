#!/bin/sh
########################################################################
# Script bdds_health.sg
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
    echo " "
    echo "               Usage: $0"
    echo " "
    echo "       Prerequisites: - uptime"
	echo "                      - who"
	echo "                      - mpstat"
	echo "                      - free"
	echo "                      - pgrep"
	echo "                      - named-checkconf"
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
server=`hostname`
scriptFolder=$(dirname $(readlink -f $0))
log="${scriptFolder}/${script%.sh}_${server}_$(date '+%Y%m%d-%H%M%S').log"
> $log
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #";
  elif [ "$2" == "debug" ]; then logPrefix="# DEBUG #"
  elif [ "$2" == "error" ]; then logPrefix="# ERROR #"; fi
  # build message
  if [ $debug -eq 1 ] && [ "$2" == "debug" ]; then
     echo -e "${logPrefix} $1"
     echo -e "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  elif [ $debug -eq 0 ] && [ "$2" == "debug" ]; then
     echo -e "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  else
     echo -e "${logPrefix} $1"
     echo -e "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
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
# Function pbar()
# progress bar for loop
#######################################################################
function pbar() {
  let _progress=(${1}*100/${2}*100)/100
  let _done=(${_progress}*4)/10
  let _left=40-$_done
  _fill=$(printf "%${_done}s")
  _empty=$(printf "%${_left}s")
  #printf "\r# TREND #    [${_fill// /#}${_empty// /-}] ${_progress}%%"
  printf "\r# TREND #    ${1} of ${2}"
}
#
#######################################################################
# Main program
#######################################################################
# debug
[[ ! -z $debug ]] && msg "debug mode enabled" debug
# validate prerequisites
msg "validation of prerequisites"
declare -a prereq=("uptime" "who" "mpstat" "free" "pgrep" "named-checkconf")
for program in "${prereq[@]}"; do
  if ! [ -x "$(command -v $program)" ]; then [[ ! -z $debug ]] && msg "prerequisite ${program} not found" error; exit
  else [[ ! -z $debug ]] && msg "validation of prerequisite ${program} done" debug; fi
done
# overview
msg "## OVERVIEW ##"
sname=`hostname`
saddress=`hostname --ip-address`
stime=`uptime | sed 's/.*up \([^,]*\), .*/\1/'`
sboot=`who -b | awk '{print $3,$4,$5}'`
msg "   Server: ${sname} ( ${saddress} )"
msg "   Uptime: ${stime} ( ${sboot} )"
# cpu
msg "## CPUs ##"
cpus=`lscpu | grep -e "^CPU(s):" | cut -f2 -d: | awk '{print $1}'`
c=0;
while [ $c -lt $cpus ]; do
      msg "   CPU$c : `mpstat -P ALL | awk -v var=$c '{ if ($2 == var ) print $3 }' `"
	  (( c++ ))
done
# process
msg "## PROCESSES ##"
pmem="process_mem.txt"
pcpu="process_cpu.txt"
ps aux | awk '{print $2, $4, $6, $11}' | sort -k3rn | head -n 10 > ${pmem}
if [[ ! -f "$pmem" ]] ; then msg "can not access ${pmem}" error
else
   msg "// Top 10 Processes by Memory"
   IFS=$'\n'; for pm in `cat $pmem`; do msg "   ${pm}"; done; unset IFS
fi
top b -n1 | head -n 17 | tail -n 10 > ${pcpu}
if [[ ! -f "$pcpu" ]] ; then msg "can not access ${pcpu}" error
else
   msg "// Top 10 Processes by CPU"
   IFS=$'\n'; for pc in `cat $pcpu`; do msg "   ${pc}"; done; unset IFS
fi
# filesystem
msg "## FILESYSTEM ##"
fsystem="filesystem.txt"
df -Pkh | grep -v 'Filesystem' > ${fsystem}
if [[ ! -f "$fsystem" ]] ; then msg "can not access ${fsystem}" error
else
   declare -i cmark=40
   declare -i wmark=30
   msg "   from ${cmark}% critical" debug
   msg "   from ${wmark}% warning" debug
   IFS=$'\n'
   for fs in `cat $fsystem`; do
       usage=`echo $fs | awk '{print $5}' | cut -f1 -d%`
	   if [ $usage -ge $cmark ]; then status='critical:'
	   elif [ $usage -ge $wmark ]; then status='warning: '
	   else status='normal:  '; fi
	   msg "   ${status} ${fs}"
   done
   unset IFS
fi
# memory
msg "## MEMORY ##"
memtotal=`free -m | head -2 | tail -1| awk '{print $2}'`
memused=`free -m | head -2 | tail -1| awk '{print $3}'`
memfree=`free -m | head -2 | tail -1| awk '{print $4}'`
msg "// Memory"
msg "   total: ${memtotal} used: ${memused} free: ${memfree}"
swaptotal=`free -m | tail -1| awk '{print $2}'`
swapused=`free -m | tail -1| awk '{print $3}'`
swapfree=`free -m |  tail -1| awk '{print $4}'`
msg "// SWAP"
msg "   total: ${swaptotal} used: ${swapused} free: ${swapfree}"
# version
msg "## VERSION ##"
version=`cat /var/patch/release/version.dat`
msg "   ${version}"
# patch
msg "## PATCHES ##"
patch="patch.txt"
cat /var/patch/patchDb.csv > ${patch}
if [[ ! -f "$patch" ]] ; then msg "can not access ${patch}" error
else
   IFS=$'\n'
   for pt in `cat $patch`; do
	   msg "   $( echo $pt | awk -F"," '{print $2}' )"
   done
   unset IFS
fi
# services
msg "## SERVICES ##"
namedconf="/replicated/jail/named/etc/named.conf"
if [[ ! -s "$namedconf" ]] ; then msg "DNS not active"
else
   dns=`pgrep named`
   msg "// DNS active ( ${dns} )"
   msg "   ${namedconf}" debug
   zones="zones.txt"
   named-checkconf -p -t /replicated/jail/named \
                        | sed -r 's/^\s+//g'  \
						| egrep "^zone \"" \
						| egrep -v -i "\"\.\"|localhost|127\.in-addr|0\.ip6|policy" \
						| awk -F"\"" '{print $2}' \
						> ${zones}
	echo "debug.test.zone" >> ${zones}
    zrows=$(cat $zones | wc -l | awk '{$1=$1};1')
	if [ $zrows -eq 0 ]; then msg "no zone(s) passed" debug
	else
	   declare -i zcount=1
	   msg "   testing ${zrows} zones"
	   declare -a types=("SOA" "NS" "A" "AAAA")
	   for zone in `cat $zones`; do
		   declare -i hits=0
		   for type in "${types[@]}"; do
		       if [[ $(dig +time=2 +tries=2 +noedns +short @$saddress $zone $type | egrep -v "connection timed out") ]]; then
		       ((hits++)); fi
		   done # types
		   if [[ "$hits" -eq 0 ]]; then printf '\n'; msg "   failure for $zone ($zcount of $zrows)" error; fi
		   printf "\r# ----- #    ${zcount} of ${zrows}"
		   (( zcount++ ))
	   done # zones
	   printf "\n"
	fi
fi
dhcpdconf="/replicated/etc/dhcpd.conf"
if [[ ! -s "$dhcpdconf" ]] ; then msg "DHCP not active"
else
   dhcp=`pgrep dhcpd`
   msg "// DHCP active ( ${dhcp} )"
   msg "   ${dhcpdconf}" debug
   leases="leases.txt"
   cat /replicated/var/state/dhcp/dhcpd.leases \
       | grep \
	     -e '^lease ' \
		 -e '^  binding state' \
		 -e '^  hardware ethernet' \
		 -e } > ${leases}.1
   sed -e "s/^lease \(.*\) {$/\1~/" \
       -e "s/^  binding state \(.*\);$/\1~/" \
	   -e "s/^  hardware ethernet \(.*\);$/\1~/" \
	   -e "s/^}//" ${leases}.1 > ${leases}.2
   sed -e ":'loop';/~$/N;s/~\n/,/;t'loop'" \
       -e "s/,$//" \
	   -e "s/,/\t/g" ${leases}.2 | sort > ${leases}.3
   sed -e'$!N;/^\(.*\)\n\1$/!P;D' ${leases}.3 > ${leases}.4
   cat ${leases}.4 > ${leases}.log &
   dhcpfree=$(grep -o -w 'free' ${leases}.log | wc -w)
   dhcpactive=$(grep -o -w 'active' ${leases}.log | wc -w)
   dhcpbackup=$(grep -o -w 'backup' ${leases}.log | wc -w)
   msg "   free leases:   ${dhcpfree}"
   msg "   active leases: ${dhcpactive}"
   msg "   backup leases: ${dhcpbackup}"
fi
# clean-up
msg "## CLEAN-UP ##"
cleaner ${pmem}
cleaner ${pcpu}
cleaner ${fsystem}
cleaner ${patch}
cleaner ${zones}
cleaner "${leases}.*"
#EOF