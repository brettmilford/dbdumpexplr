#!/bin/sh -e

trap ctrl_c INT

ctrl_c () {
  _mysqld_stop
}

_mysqld_start () {

  [ -d $SNAP_USER_DATA/var/lib/mysql ] || _mysqld_init
  mysqld \
    --datadir=$SNAP_USER_DATA/var/lib/mysql \
    --secure-file-priv=$SNAP_USER_DATA/var/lib/mysql-files \
    --log_error=$SNAP_USER_DATA/var/log/mysql/error.log \
    --socket=$SNAP_USER_DATA/var/run/mysqld/mysqld.sock &

  until [ -S $SNAP_USER_DATA/var/run/mysqld/mysqld.sock ]; do sleep 1; done
}

_mysqld_stop () {

  [ -f $SNAP_USER_DATA/var/lib/mysql/primary.pid ] && {
    kill -TERM $(cat $SNAP_USER_DATA/var/lib/mysql/primary.pid)
    rm $SNAP_USER_DATA/var/lib/mysql/primary.pid
  }
}
_mysqld_init () {

  mkdir -p $SNAP_USER_DATA/var/lib/mysql
  mkdir -p $SNAP_USER_DATA/var/lib/mysql-files
  chmod 700 $SNAP_USER_DATA/var/lib/mysql-files
  mkdir -p $SNAP_USER_DATA/var/log/mysql
  mkdir -p $SNAP_USER_DATA/var/run/mysqld

  mysqld --initialize-insecure \
    --datadir=$SNAP_USER_DATA/var/lib/mysql \
    --log_error=$SNAP_USER_DATA/var/log/mysql/error.log
}

_import () {

    _mysqld_start

    if [ "${1##*.}" = "gz" ]; then
      zcat ${1} | mysql --socket=$SNAP_USER_DATA/var/run/mysqld/mysqld.sock -u root -f
    else
      cat ${1} | mysql --socket=$SNAP_USER_DATA/var/run/mysqld/mysqld.sock -u root -f
    fi

    _mysqld_stop
}

_export () {

    _DATE=$(date +%Y-%m-%dT%H-%M-%S)

    _mysqld_start

    mysqldump -u root ${1} \
	    --ignore-table=mysql.innodb_index_stats \
	    --ignore-table=mysql.innodb_table_stats \
	    > ${SNAP_USER_COMMON}/${1}_${_DATE}.sql

    _mysqld_stop

    echo "Database exported to: ${SNAP_USER_COMMON}/${1}_${_DATE}.sql"
}

_cli () {

    _mysqld_start

    mysql --socket=$SNAP_USER_DATA/var/run/mysqld/mysqld.sock -u root $@

    _mysqld_stop
}

_reset () {

  _mysqld_stop

  until [ -S $SNAP_USER_DATA/var/run/mysqld/mysqld.sock ]; do sleep 1; done
  rm -rf $SNAP_USER_DATA

  _mysqld_init

}

case "${1:-h}" in
  --import)
    shift
    _import $@
  ;;

  --export)
    shift
    _export $@
  ;;

  --reset)
    shift
    _reset $@
  ;;


  -h|--help|help)
    echo "${0} [--import | --export | --reset ] [ CLI PARAMS ]"
  ;;

  *)
    _cli $@
  ;;
esac
