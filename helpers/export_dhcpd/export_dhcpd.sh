#!/usr/local/bin/bash
########################################################################
# Script export_dhcpd.sh
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage () {
    echo " "
    echo "          Usage: $0 <ip-ranges> <dhcpd.conf>"
    echo "    <ip-ranges>: list of IPv4 CIDR ranges (one entry per line)"
    echo "   <dhcpd.conf>: name of config file"
    echo " "
    echo "  Prerequisites: rgxg"
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
function msg() {
  if [ -z "$2" ]; then logPrefix="# ----- #"
  elif [ "$2" == "debug" ]; then logPrefix="# DEBUG #"
  elif [ "$2" == "error" ]; then logPrefix="# ERROR #"; fi
  # build message
  if [ $debug -eq 1 ] && [ "$2" == "debug" ]; then
     echo "${logPrefix} $1"
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  elif [ $debug -eq 0 ] && [ "$2" == "debug" ]; then
     echo "[$(date '+%Y%m%d-%H%M%S')] : ${logPrefix} $1" >> $log
  else
     echo "${logPrefix} $1"
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
# get and validate parameters
args=2
if [ "$#" -lt "$args" ]; then usage; else ranges=$1; config=$2; fi
if [[ ! -f "$ranges" ]] ; then msg "ranges file ${ranges} not found" error; exit; fi
if [[ ! -f "$config" ]] ; then msg "config file ${config} not found" error; exit; fi
# debug
[[ ! -z $debug ]] && msg "debug mode enabled" debug
# validate prerequisites
msg "validation of prerequisites"
declare -a prereq=("rgxg")
for program in "${prereq[@]}"; do
  if ! [ -x "$(command -v $program)" ]; then [[ ! -z $debug ]] && msg "prerequisite ${program} not found" error; exit
  else [[ ! -z $debug ]] && msg "validation of prerequisite ${program} done" debug; fi
done
# sort list of ranges
msg "sorting list of ranges ( ${ranges} )"
sortranges=${ranges%.*}_sort.csv
cat $ranges | sort | uniq > $sortranges
if [[ ! -f "$sortranges" ]] ; then msg "can not sort list of ranges ( ${sortranges} )" error; exit; fi
# clean-up list of ranges
msg "cleaning list of ranges ( ${sortranges} )"
cleanranges=${ranges%.*}_clean.csv
egrep '[0-9]{1,3}(?:\.[0-9]{1,3}){0,3}/[0-9]+' $sortranges > $cleanranges
if [[ ! -f "$cleanranges" ]] ; then msg "can not clean list of ranges ( ${cleanranges} )" error; exit; fi
rangerows=$(cat $sortranges | wc -l | awk '{$1=$1};1')
cleanrows=$(cat $cleanranges | wc -l | awk '{$1=$1};1')
msg "${rangerows} given ranges ( ${sortranges} )"
msg "${cleanrows} cleaned ranges ( ${cleanranges} )"
# flatten config file
msg "flattening config file ( ${config} )"
flatconfig=${config%.*}_flat.config
cat $config | tr -d '\n' | tr -s ' ' | sed 's/subnet /\nsubnet /g' > $flatconfig
if [[ ! -f "$flatconfig" ]] ; then msg "can not flatten config file ( ${flatconfig} )" error; exit; fi
# filter confg file
msg "filtering config file ( ${flatconfig} )"
filterconfig=${config%.*}_filter.config
for range in `cat $cleanranges`; do
    regex=( $(rgxg cidr $range) )
    egrep "${regex}" $flatconfig >> $filterconfig
    unset $regex
done
if [[ ! -f "$filterconfig" ]] ; then msg "can not filter config file ( ${filterconfig} )" error; exit; fi
# sort config file
msg "sorting config file ( ${filterconfig} )"
sortconfig=${config%.*}_sort.config
cat $filterconfig | sort | uniq > $sortconfig
if [[ ! -f "$sortconfig" ]] ; then msg "can not sort config file ( ${sortranges} )" error; exit; fi
# resulting config file
resultconfig=${config%.*}_result.config
cp $sortconfig $resultconfig
if [[ ! -f "$resultconfig" ]] ; then msg "can not result config file ( ${sortranges} )" error; exit; fi
msg "resulting config file ( ${resultconfig})"
# clean-up
cleaner $sortranges
cleaner $cleanranges
cleaner $flatconfig
cleaner $filterconfig
cleaner $sortconfig



