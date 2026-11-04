#!/bin/bash
networks='networks.txt'
export=reverse-zones.txt
> $export
#######################################################################
# Function buildzone()
# converts network into reverse zone
#######################################################################
function buildzone() {
  netinput="$1"
  cidr=${netinput#*/}
  if [[ "${cidr}" == "8" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $1,"in-addr.arpa"}' >> $export
  elif [[ "${cidr}" == "16" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $2,$1,"in-addr.arpa"}' >> $export
   elif [[ "${cidr}" == "24" ]] ; then
     echo ${netinput} | awk -F. '{OFS="."; print $3,$2,$1,"in-addr.arpa"}' >> $export
  else
     echo "CIDR ${cidr} of Network ${netinput} not supported"
  fi
}
#######################################################################
# Main
#######################################################################
echo "# Start #"
netcount=$(wc -l ${networks} | awk '{ print $1 }')
((netcount++))
echo "Working on ${netcount} Networks in Import File ${networks}"
for network in `cat $networks`
do
  buildzone ${network}
done
if [[ ! -f "${export}" ]] ; then
   echo "Couldn't create File ${export}"
else
   expcount=$(wc -l ${export} | awk '{ print $1 }')
   echo "${expcount} Reverse Zones in Export File ${export}"
fi
echo "# EOL #"
#######################################################################
# EOF
#######################################################################
