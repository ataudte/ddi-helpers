#!/bin/bash
# usage hints
function usage() {
  echo
  echo -e "\tUsage: $0 <server-list> <zone-list>"
  echo
  exit
}
# check arguments and set variables
args=2
if [ "$#" -lt "$args" ]; then usage; else servers=$1; zones=$2; fi
if [[ ! -e $servers ]]; then echo "file $servers doesn't exist"; exit; fi
if [[ ! -e $zones ]]; then echo "file $zones doesn't exist"; exit; fi
declare -a types=("SOA" "NS" "A")
# count servers and zones
srows=$(cat $servers | wc -l)
if [ $srows -eq 0 ]; then echo "no server(s) passed"; exit; else scount=0; fi
zrows=$(cat $zones | wc -l)
if [ $zrows -eq 0 ]; then echo "no zone(s) passed"; exit; else zcount=0; fi
# log file
script=`basename $0`
log=${script%.sh}_$(date '+%Y%m%d-%H%M%S').log
> $log
# run
echo "# Start"
echo -e "\tServers: $servers ($srows)"
echo -e "\tZones:   $zones ($zrows)"
echo -e "\tTypes:   ${types[*]}"
for zone in `cat $zones`; do
  (( zcount++ ))
  for dns in `cat $servers`; do
    (( scount++ ))
    declare -i hits=0
    for type in "${types[@]}"; do
      if [[ $(dig +time=2 +tries=2 +noedns +short @$dns $zone $type | egrep -v "connection timed out") ]]; then
         ((hits++))
      fi
    done # types
    if [[ "$hits" -eq 0 ]]; then
       echo "failure $hits-of-${#types[@]} for $zone ($zcount of $zrows) at $dns ($scount of $srows)" | tee -a $log
    else
       echo "success $hits-of-${#types[@]} for $zone ($zcount of $zrows) at $dns ($scount of $srows)" | tee -a $log
    fi
  done # servers
  scount=0
done # zones
echo "# EOL"
