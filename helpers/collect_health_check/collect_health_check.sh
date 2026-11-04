#!/bin/sh
########################################################################
# Script collect_health_check.sh
# run ...
########################################################################
#
#######################################################################
# Function usage()
# usage hints
#######################################################################
function usage() {
  echo
  echo -e "\tUsage: $0 [-l <server-list>]"
  echo -e "\t       -l:  file with list of BDDS"
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
# Main program
#######################################################################
# check list of servers
args=1
if [ "$#" -lt "$args" ]; then usage; else file=$1; fi
if [[ ! -e $file ]]; then msg "# Oops! file $file doesn't exist"; exit; fi
bddslist="clean_"$file
sed '/^\s*$/d' $file  | sort | uniq > $bddslist
if [[ ! -e $bddslist ]]
then
  msg "# Oops! can't access cleaned list ($bddslist)"
  exit
else
  msg "# file $file cleaned ($bddslist)"
fi
rows=$(cat $bddslist | wc -l)
if [ $rows -eq 0 ]
then
  msg "# Oops! no server(s) passed"
  exit
else
  msg "# $rows server(s) found in $bddslist"
  count=0
fi
# get password from input
echo -n "# enter BDDS password: " && read -es bddspwd && echo "thanks"
# read and progress file
for bdds in $(cat "$bddslist"); do
    (( count++ ))
    msg "# working on ${bdds} ($count of $rows)"
    # check BDDS in DNS
    checkdns="true"
    if [[ true == "$checkdns" ]]; then
       if ! host $bdds | grep -q address; then
          msg "# Oops! host ${bdds} not found"
          continue
       fi
    fi
    # check port 22
    timeout 10 sh -c "</dev/tcp/${bdds}/22" > /dev/null 2>&1
    if [[ $? == 0 ]]; then
       msg "# port 22 on server ${bdds} reachable"
       # build reservoir
       folder="/tmp/$(date '+%Y-%m')"
       if [[ -e $folder ]]
       then
         msg "# reservoir already exists (${folder})"
       else
         mkdir $folder
         if [[ ! -e $folder ]]; then msg "# Oops! can't build reservoir (${folder})"; exit; fi
       fi
       # login and run
       msg "# working on datarake for server ${bdds}"
       { sleep 5; echo -e $bddspwd; } | /usr/bin/script -q /dev/null -c "ssh -q -o StrictHostKeyChecking=no -t root@$bdds \"/usr/local/bluecat/datarake.sh > /dev/null 2>&1\" && echo \"# datarake for server ${bdds} done\""
       msg "# loading datarake from server ${bdds}"
       { sleep 5; echo $bddspwd; } | /usr/bin/script -q /dev/null -c "scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$bdds:/tmp/bcn-support.* $folder/. && echo \"# SCP of datarake from server ${bdds} successful\""
       msg "# clean-up of datarake at server ${bdds}"
       { sleep 5; echo -e $bddspwd; } | /usr/bin/script -q /dev/null -c "ssh -q -o StrictHostKeyChecking=no -t root@$bdds \"rm /tmp/bcn-support.*\" && echo \"# clean-up on server ${bdds} done\""
       msg "# working on bdds_health for server ${bdds}"
       { sleep 5; echo -e $bddspwd; } | /usr/bin/script -q /dev/null -c "ssh -q -o StrictHostKeyChecking=no -t root@$bdds \"/root/bdds_health.sh  > /dev/null 2>&1\" && echo \"# bdds_health for server ${bdds} done\""
       msg "# loading bdds_health from server ${bdds}"
       { sleep 5; echo $bddspwd; } | /usr/bin/script -q /dev/null -c "scp -q -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@$bdds:/root/bdds_health_* $folder/. && echo \"# SCP bdds_health from server ${bdds} successful\""
    else
       msg "# Oops! server ${bdds} not reachable"
    fi
msg "# done with ${bdds}"
done
msg "# database backup started"
/usr/bin/perl /usr/local/bcn/backup.pl -i default > /dev/null 2>&1
today="$(date '+%Y%m%d%H')"
echo -n "# "
while [ ! -f /data/backup/backup_default_*${today}*.bak ]; do echo -n "."; sleep 5; done; echo
backup="$(ls -t /data/backup/backup_default_*${today}*.bak | head -n1)"
mv $backup ${folder}/.
if ls ${folder}/*.bak &> /dev/null
then
  msg "# database backup finished"
else
  msg "# Oops! backup missing in reservoir (${folder})"
fi
msg "# database datarake started"
/usr/local/bluecat/datarake.sh > /dev/null 2>&1
dbrake="$(ls -t /tmp/bcn-support.*PROTEUS*.tgz | head -n1)"
mv $dbrake ${folder}/.
if ls ${folder}/bcn-support.*PROTEUS*.tgz &> /dev/null
then
  msg "# database datarake finished"
else
  msg "# Oops! datarake missing in reservoir (${folder})"
fi
msg "# rrdtool collection started"
tar czf ${folder}/rrdtool.tar.gz /data/rrdtool/ > /dev/null 2>&1
if ls ${folder}/rrdtool.tar.gz &> /dev/null
then
  msg "# rrdtool collection finished"
else
  msg "# Oops! rrdtool missing in reservoir (${folder})"
fi
bundle=$(ls ${folder} | wc -l)
msg "# ${bundle} files in reservoir (${folder})"
#EOF
