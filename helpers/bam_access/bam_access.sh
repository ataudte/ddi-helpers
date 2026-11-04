#!/bin/bash
set -euo pipefail

export LC_ALL=C
export LANG=C

DB="proteusdb"
DBUSER="postgres"
PSQL="/usr/bin/psql -X -qAt -U $DBUSER -d $DB"

ADMIN_USER="admin"
BLUECAT_USER="bluecat"
PASSWORD_HASH="21232F297A57A5A743894A0E4A801FC3"

user_id() {
  $PSQL -c "SELECT id FROM entity WHERE discriminator='NUSR' AND name='$1' ORDER BY id DESC LIMIT 1;"
}
user_exists() {
  local id; id="$(user_id "$1")"
  [[ -n "${id:-}" ]]
}

change_password_for() {
  local u="$1"
  echo "Changing password for '$u'"
  $PSQL -c "
    SELECT nextval('history_id_seq');
    UPDATE metadata_value AS mv
    SET text = '$PASSWORD_HASH'
    FROM entity AS e, metadata_field AS f
    WHERE mv.owner_id = e.id
      AND f.id = mv.field_id
      AND e.discriminator = 'NUSR'
      AND e.name = '$u'
      AND f.name = 'password';
  " >/dev/null
}

create_bluecat() {
	echo "Creating user '$BLUECAT_USER'"
	/usr/bin/psql -U postgres proteusdb -c "select nextval('history_id_seq');insert into entity ( discriminator , version , inherit_right , name , parent_id , association_id , long1) values ( 'NUSR' , 6 , 't' , 'bluecat' , 1 , 2 , 16 );"
	ID=`/usr/bin/psql -U postgres proteusdb -c "select id from entity where discriminator = 'NUSR' and name = 'bluecat';"|grep -vE "id|----|row|^$"| tr -d '[[:space:]]'`
	MAX=`/usr/bin/psql -U postgres proteusdb -c "select max(id) from metadata_value;"|grep -vE "max|----|row|^$"| tr -d '[[:space:]]'`
	MAX1=$((MAX + 1))
	MAX2=$((MAX + 2))
	MAX3=$((MAX + 3))
	MAX4=$((MAX + 4))
	/usr/bin/psql -U postgres proteusdb -c "select nextval('history_id_seq');insert into metadata_value (id , version , owner_id , text , field_id) values ( $MAX1 , 0 , $ID , 'LEVEL_FULL' , 65565);insert into metadata_value (id , version , owner_id , text , field_id) values ( $MAX2 , 0 , $ID , 'LEVEL_1' , 65567);insert into metadata_value (id , version , owner_id , text , field_id) values ( $MAX3 , 0 , $ID , '21232F297A57A5A743894A0E4A801FC3' , 65566);insert into metadata_value (id , version , owner_id , text , field_id) values ( $MAX4 , 0 , $ID , 'bluecat@example.com ' , 327709);"
}

# parse -b
FLAG_B=0
while getopts ":b" opt; do
  case "$opt" in
    b) FLAG_B=1 ;;
    \?) echo "Unknown option: -$OPTARG" >&2; exit 2 ;;
  esac
done
shift $((OPTIND - 1))

# main
if (( FLAG_B == 1 )); then
  if user_exists "$BLUECAT_USER"; then
    change_password_for "$BLUECAT_USER"
  else
    create_bluecat
  fi
  exit 0
fi

if user_exists "$ADMIN_USER"; then
  change_password_for "$ADMIN_USER"
else
  if user_exists "$BLUECAT_USER"; then
    change_password_for "$BLUECAT_USER"
  else
    create_bluecat
  fi
fi
