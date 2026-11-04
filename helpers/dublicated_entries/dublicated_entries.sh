#!/bin/sh
########################################################################
# Script dublicated-entries.sh
# Find Hosts with multiple IP Addresses
# Find IP Addresses with multiple Hosts
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
    echo "   "
    echo "   Usage: $0 [-d] [-n <zone-name>] [-z <zone-file>]"
    echo "      -d: debug mode"
    echo "      -n: name of zone to validate"
    echo "      -z: zone file to validate"
    echo "   "
    echo "   Prerequisites: - named-checkzone (bind-utils)"
    echo "                  - awk"
    echo "   "
    exit
}
#
#######################################################################
# Function msg()
# print and log message
#######################################################################
log=dublicated-entries.log
> $log
function msg() {
  echo "$*"
  echo "[$(date '+%Y%m%d-%H%M%S')] : $*" >> $log
}
#
#######################################################################
# Function cleanms()
# delete timestamps from dynamic MS-DNS zones
#######################################################################
function cleanms() {
  msfile="$*"
  if egrep -q "\[AGE:[0-9]{7}\]*" "${msfile}"; then
    msg "# clean-up of MS-DNS timestamps in zone file ${msfile} #"
    sed -E "s/\[AGE:[0-9]{7}\]*//" "${msfile}" > "${msfile}.tmp" && mv "${msfile}.tmp" "${msfile}"
    [[ ! -z $debug ]] && msg "  > MS-DNS timestamps deleted in zone file ${msfile} #"
  fi
}
#
#######################################################################
# Function canzonefile()
# canonicalization of zone files
#######################################################################
function canzonefile() {
  prefix="$1"
  zfile="$2"
  zname="$3"
  canfile="$(date '+%Y%m%d-%H%M%S')_${prefix}_${zfile}"
  named-checkzone -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  if [[ ! -f "${canfile}" ]] ; then
     msg "  > Oops! canonicalization of zone file ${zfile} failed #"
     exit
  else
     [[ ! -z $debug ]] && msg "  > canonicalization of zone file ${zfile} done (${canfile})"
  fi
}
#
#######################################################################
# Function deleterr()
# delete records of specific type in zone file
#######################################################################
function deleterr() {
  rrfile="$1"
  rrtype="$2"
  if egrep -q "[0-9]+[[:space:]]IN[[:space:]]${rrtype}" "${rrfile}"; then
    [[ ! -z $debug ]] && msg "  > clean-up of ${type} records #"
    sed -E "/[0-9]+[[:space:]]IN[[:space:]]${rrtype}/d" "${rrfile}" > "${rrfile}.tmp" && mv "${rrfile}.tmp" "${rrfile}"
    [[ ! -z $debug ]] && msg "    |_ ${rrtype} records in ${rrfile} deleted"
  fi
}
#
#######################################################################
# Function validaterr()
# validate dublicated entries in zone file
#######################################################################
function validaterr() {
  valtype="$1"
  valfile="$2"
  valname="$3"
  vallog="$(date '+%Y%m%d-%H%M%S')_${valname}_${valtype}-validation.log"
  if [[ $valtype == "host" ]]; then
     awk 'cnt[$1]++{if (cnt[$1]==2) print prev[$1]; print} {prev[$1]=$0}' ${valfile} > ${vallog}
  elif [[ $valtype == "ip" ]]; then
     awk 'cnt[$5]++{if (cnt[$5]==2) print prev[$5]; print} {prev[$5]=$0}' ${valfile} > ${vallog}
  else
     msg "# Oops! unsupported validation type ${valtype} #"
     exit
  fi
  if [[ -f "$vallog" ]] ; then
     lines=$(wc -l "${vallog}" | awk '{print $1}')
     [[ ! -z $debug ]] && msg "           |_ results of ${valtype}-validation can be found in file ${vallog} (${lines} lines)"
     [[ -z $debug ]] && msg "# results of ${valtype}-validation can be found in file ${vallog} (${lines} lines) #"
  else
     [[ ! -z $debug ]] && msg "           |_ Oops! can't find file ${vallog}"
     [[ -z $debug ]] && msg "# Oops! can't find file ${vallog} #"
  fi
}
#
#######################################################################
# Main program
#######################################################################
# record types to ignore
declare -a records=("SOA" "NS" "SRV" "MX" "TXT" "DNSKEY" "CNAME")
# get parameters
debug=
while getopts "dn:z:" opt; do
      case "${opt}" in
           d)
             debug=1
             [[ ! -z $debug ]] && msg "# debug mode enabled #"
            ;;
           n)
             zonename=${OPTARG}
             ;;
           z)
             zonefile=${OPTARG}
             if [[ ! -f "$zonefile" ]] ; then
                msg "# Oops! zone file ${zonefile} not found #"
                exit
             fi
             ;;
           *)
             usage
             ;;
      esac
done
shift $((OPTIND-1))
# validtae all parameters are set
if [ -z "${zonename}" ] || [ -z "${zonefile}" ]; then
    usage
fi
# validate prerequisites
msg "# validation of prerequisites #"
declare -a prereq=("named-checkzone" "awk")
for program in "${prereq[@]}"
do
  if ! [ -x "$(command -v $program)" ]; then
     [[ ! -z $debug ]] && msg "  > Oops! prerequisite ${program} not found"
     exit
  else
     [[ ! -z $debug ]] && msg "  > validation of prerequisite ${program} done "
  fi
done
# validate zone content
cleanms ${zonefile}
# canonicalization of zone files
msg "# canonicalization of zone file #"
canfile=""
canzonefile "canonised" ${zonefile} ${zonename}
canzonefile="${canfile}"
# clean-up records
msg "# clean-up of resource records #"
for type in "${records[@]}"
do
  deleterr $canzonefile ${type}
done
# validation of zone files
msg "# validation of zone file ${zonefile} #"
if [[ -f "$canzonefile" ]] ; then
   [[ ! -z $debug ]] && msg "  > start: validation of hosts with multiple IPs in zone ${zonename}"
   validaterr 'host' ${canzonefile} ${zonename}
   [[ ! -z $debug ]] && msg "  > end:   validation of hosts with multiple IPs in zone ${zonename}"
   [[ ! -z $debug ]] && msg "  > start: validation of IPs with multiple hosts in zone ${zonename}"
   validaterr 'ip' ${canzonefile} ${zonename}
   [[ ! -z $debug ]] && msg "  > end:   validation of IPs with multiple hosts in zone ${zonename}"
fi
msg "# validation of zone ${zonename} done #"
# rename log file
newlog="$(date '+%Y%m%d-%H%M%S')_${zonename}_process.log"
mv ${log} ${newlog}
if [[ -f "$newlog" ]] ; then
   [[ ! -z $debug ]] && echo "# results of process can be found in file ${newlog} #"
else
   [[ ! -z $debug ]] && echo "# Oops! can't rename file ${log} #"
fi
#EOF
