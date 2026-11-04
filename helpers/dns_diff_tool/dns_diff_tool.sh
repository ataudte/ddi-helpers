#!/bin/sh
########################################################################
# Script dns_diff_tool.sh
# Compare two DNS Zone Files
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
    echo "   "
    echo "   Usage: $0 [-d] [-n <zone-name>] [-1 <pre-zone-file>] [-2 <post-zone-file>]"
    echo "      -d: display all details"
    echo "      -n: name of DNS zone to compare"
    echo "      -1: pre-migration zone file"
    echo "      -2: post-migration zone file"
    echo "   "
    echo "   Prerequisites: - named-checkzone (bind-utils)"
    echo "                  - ldns-compare-zones (ldns-utils)"
    echo "   "
    exit
}
#
#######################################################################
# Function msg()
# print and log message
#######################################################################
log=dns_diff_tool.log
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
    msg "# Hint! zone file ${msfile} contains MS-DNS timestamps #"
    sed -E "s/\[AGE:[0-9]{7}\]*//" "${msfile}" > "${msfile}.tmp" && mv "${msfile}.tmp" "${msfile}"
    msg "  > MS-DNS timestamps deleted in zone file ${msfile} #"
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
  canfile="$(date '+%Y%m%d-%H%M%S')_${prefix}.can.${zfile}"
  named-checkzone -D -o ${canfile} ${zname} ${zfile} > /dev/null 2>&1
  if [[ ! -f "${canfile}" ]] ; then
     msg "# Oops! canonicalization of ${prefix}-migration zone file ${zfile} failed #"
     exit
  else
     msg "  > canonicalization of ${prefix}-migration zone file ${zfile} done (${canfile})"
  fi
}
#
#######################################################################
# Function deleterr()
# delete NS records in zone file
#######################################################################
function deleterr() {
  rrfile="$1"
  rrtype="$2"
  if egrep -q "[0-9]+[[:space:]]IN[[:space:]]${rrtype}" "${rrfile}"; then
    sed -E "/[0-9]+[[:space:]]IN[[:space:]]${rrtype}/d" "${rrfile}" > "${rrfile}.tmp" && mv "${rrfile}.tmp" "${rrfile}"
    msg "  > ${rrtype} records in ${rrfile} deleted"
  fi
}
#
#######################################################################
# Main program
#######################################################################
# record types to ignore
declare -a records=("NS")
# get parameters
debug=
while getopts ":dn:1:2:" opt; do
      case "${opt}" in
           d)
             debug=1
            ;;
           n)
             zonename=${OPTARG}
             msg "# DNS diff for zone ${zonename} #"
             if [[ -z $debug ]] ; then
                msg " > details of diff results disabled"
             else
                msg " > details of diff results enabled"
             fi
             ;;
           1)
             prezonefile=${OPTARG}
             if [[ ! -f "$prezonefile" ]] ; then
                msg "# Oops! pre-migration zone file ${prezonefile} not found #"
                exit
             fi
             ;;
           2)
             postzonefile=${OPTARG}
             if [[ ! -f "$postzonefile" ]] ; then
                msg "# Oops! post-migration zone file ${postzonefile} not found #"
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
if [ -z "${zonename}" ] || [ -z "${prezonefile}" ] || [ -z "${postzonefile}" ]; then
    usage
fi
# validate prerequisites
msg "# validation of prerequisite #"
declare -a prereq=("named-checkzone" "ldns-compare-zones")
for program in "${prereq[@]}"
do
  if ! [ -x "$(command -v $program)" ]; then
     msg "  > Oops! prerequisite ${program} not found"
     exit
  else
     msg "  > validation of prerequisite ${program} done "
  fi
done
# validate zone content
cleanms ${prezonefile}
cleanms ${postzonefile}
# canonicalization of zone files
msg "# canonicalization of zone files #"
canfile=""
canzonefile "pre" ${prezonefile} ${zonename}
precanzonefile="${canfile}"
canfile=""
canzonefile "post" ${postzonefile} ${zonename}
postcanzonefile="${canfile}"
# clean-up records
for type in "${records[@]}"
do
  msg "# clean-up of ${type} records #"
  deleterr $precanzonefile ${type}
  deleterr $postcanzonefile ${type}
done
# comparison of zone files
msg "# comparison of zone files #"
if [[ -f "$precanzonefile" ]] && [[ -f "$postcanzonefile" ]] ; then
   msg "  > +NUM_INS: additional records in ${postzonefile}"
   msg "  > -NUM_DEL: additional records in ${prezonefile}"
   msg "  > ~NUM_CHG: difference in the amount or content of the records"
   msg " "
   msg "Results: "
   if [[ -z $debug ]] ; then
      msg "$(ldns-compare-zones ${precanzonefile} ${postcanzonefile})"
   else
      msg "$(ldns-compare-zones -a ${precanzonefile} ${postcanzonefile})"
   fi
   msg " "
fi
msg "# DNS diff for zone ${zonename} done #"
# rename log file
newlog="$(date '+%Y%m%d-%H%M%S')_${zonename}_${prezonefile}_${postzonefile}.log"
mv ${log} ${newlog}
if [[ -f "$newlog" ]] ; then
   echo "# results can be found in file ${newlog} #"
else
   echo "# Oops! can't rename file ${log} #"
fi
#EOF
