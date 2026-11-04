#!/bin/bash
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo -e "\tUsage: $0 <zone-list>"
  echo -e "\t          <zone-list>:  file with associated deployment roles"
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
log=${script%.sh}.log
> $log
function msg() {
	if [ $debug -eq 1 ] && [ "$2" == "debug" ]
	then
		echo -e "DEBUG $1"
		echo "[$(date '+%Y%m%d-%H%M%S')] : DEBUG $1" >> $log
	elif [ $debug -eq 1 ] && [ -z "$2" ]
	then
		echo -e "$1"
		echo "[$(date '+%Y%m%d-%H%M%S')] : $1" >> $log
	elif [ $debug -eq 0 ] && [ "$2" == "debug" ]
	then
		echo "[$(date '+%Y%m%d-%H%M%S')] : DEBUG $1" >> $log
	elif [ $debug -eq 0 ] && [ -z "$2" ]
	then
		echo -e "$1"
		echo "[$(date '+%Y%m%d-%H%M%S')] : $1" >> $log
	fi
}
#
#######################################################################
# Function buildzone()
# converts network into reverse zone
#######################################################################
function buildzone() {
  netinput="$1"
  export="$2"
  cidr=${netinput#*/}
  if [[ "${cidr}" == "8" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $1,"in-addr.arpa"}' >> $export
  elif [[ "${cidr}" == "16" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $2,$1,"in-addr.arpa"}' >> $export
   elif [[ "${cidr}" == "24" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $3,$2,$1,"in-addr.arpa"}' >> $export
  else
     msg "# Oops! CIDR ${cidr} of Network ${netinput} not supported"
  fi
}
#######################################################################
# Main
#######################################################################
# validate list of zones
args=1
if [ "$#" -lt "$args" ]; then usage; else file=$1; fi
if [[ ! -e $file ]]; then msg "# Oops! file $file doesn't exist"; exit; fi
zonelist="clean_"$file
sed '/^\s*$/d' $file | awk -F"\"" '{ print $(NF-1) }' > $zonelist
if [[ ! -e $zonelist ]]
then
  msg "# Oops! can't access cleaned list ($zonelist)"
  exit
else
  msg "# file $file cleaned ($zonelist)"
fi
inRows=$(cat $zonelist | wc -l | awk '{$1=$1};1')
if [ $inRows -eq 0 ]
then
  msg "# Oops! no zone(s) passed"
  exit
else
  msg "# $inRows zone(s) found in $zonelist"
fi
# check reverse zones
reverse="reverse_"$zonelist
egrep '[0-9]{1,3}(?:\.[0-9]{1,3}){0,3}/[0-9]+' $zonelist > $reverse
revRows=$(cat $reverse | wc -l | awk '{$1=$1};1')
if [ $revRows -eq 0 ]
then
  msg "# no reverse zone(s) passed"
else
  msg "# $revRows reverse zone(s) found in $reverse"
fi
egrep -v '[0-9]{1,3}(?:\.[0-9]{1,3}){0,3}/[0-9]+' $zonelist > $zonelist".tmp" \
      && mv $zonelist".tmp" $zonelist
for rzone in $(cat "$reverse"); do buildzone $rzone $zonelist; done
# read and progress file
result="result_"$file
awk -F"." 's="";{for(i=NF;i>0;i--) {if (i<NF) s=s "." $i; else s=$i}; print s}' $zonelist \
    | sort | awk -F"." 's="";{for(i=NF;i>0;i--) {if (i<NF) s=s "." $i; else s=$i}; print s}' \
    > $result
if [[ ! -f "${result}" ]] ; then
   msg "# Oops! file ${result} not created"
else
   outRows=$(cat $result | wc -l | awk '{$1=$1};1')
   msg "# $outRows zone(s) sorted in $result"
fi
# clean-up
rm $reverse && msg "# $reverse deleted"
rm $zonelist && msg "# $zonelist deleted"
#######################################################################
# EOF
#######################################################################
