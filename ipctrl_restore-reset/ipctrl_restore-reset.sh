#!/bin/bash

# check if an argument was provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <path_to_sql.zip_file>"
    exit 1
fi

# extract filename and directory from the provided argument
SQL_ZIP="$1"
SQL_FILE="${SQL_ZIP%.zip}"
SQL_DIR="/opt/incontrol/mysql/bin"
SQL_BIN="/opt/incontrol/mysql/bin/mysql"
SQL_USER="incadmin"
SQL_PW="incadmin"

# debugging
script=$(basename "$0")
scriptFolder=$(dirname $(readlink -f $0))
logfile="${scriptFolder}/${script%.sh}_$(date '+%Y%m%d-%H%M%S').log"
> $logfile

# copy and unpack the archive
echo "unpacking and moving sql file"
unzip -o "$(basename "$SQL_ZIP")" >> $logfile
if [ -z "$(basename "$SQL_FILE")" ]; then
    echo "ERROR: unzip failed or sql file not found in archive"
    exit 2
fi
mv "$SQL_FILE" $SQL_DIR
if [ -f "${SQL_DIR}/$(basename "$SQL_FILE")" ]; then
    echo "$(basename "$SQL_FILE") moved to ${SQL_DIR}"
else
    echo "ERROR: ${SQL_DIR}/$(basename "$SQL_FILE") does not exist"
fi

# stop incontrol
echo "stopping incontrol service"
/opt/incontrol/etc/incontrol stop >> $logfile

# start mysql
echo "starting sql server"
/opt/incontrol/etc/mysqld_start >> $logfile
echo "waiting for sql server to start"
sleep 10
# execute SQL commands
echo 'restoring database from backup'
${SQL_BIN} -u${SQL_USER} -p${SQL_PW} -e 'drop database incontrol;' 2>/dev/null >> $logfile
${SQL_BIN} -u${SQL_USER} -p${SQL_PW} -e 'create database incontrol;' 2>/dev/null >> $logfile
${SQL_BIN} -u${SQL_USER} -p${SQL_PW} -Dincontrol <${SQL_DIR}/$(basename "$SQL_FILE") 2>/dev/null >> $logfile
echo 'resetting incadmin password to default'
${SQL_BIN} -u${SQL_USER} -p${SQL_PW} -Dincontrol -e "update ipcadmin set password = 'd5408a119df521418f3307a4825607952d8e0a36cfb6b53371656b113600d421337825a59e807601' where id = 0;" 2>/dev/null >> $logfile

# stop mysql
echo "stopping sql server"
/opt/incontrol/etc/mysqld_stop >> $logfile

# start incontrol
echo "starting incontrol services"
/opt/incontrol/etc/incontrol start >> $logfile


# clean-up
if [ -f "${SQL_DIR}/$(basename "$SQL_FILE")" ]; then
    # Attempt to delete the file
    rm "${SQL_DIR}/$(basename "$SQL_FILE")"
    if [ $? -eq 0 ]; then
        echo "$(basename "$SQL_FILE") deleted successfully"
    else
        echo "ERROR: failed to delete ${SQL_DIR}/$(basename "$SQL_FILE")"
    fi
else
    echo "ERROR: ${SQL_DIR}/$(basename "$SQL_FILE") does not exist"
fi
echo "backup restoration completed"
grep -i -n "ERROR" "$logfile" | awk -F ':' '{print "Error Log -", $0}'

