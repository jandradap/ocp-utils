#!/bin/bash

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
BACKUP_DATABASES=${BACKUP_DATABASES:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
IGNORE_DATABASE=${IGNORE_DATABASE}
BACKUP_STORAGE=${BACKUP_STORAGE:-/tmp}
DATE_BACKUP=$(date +%Y%m%d)

if [[ ${DB_USER} == "" ]]; then
  echo "ERROR: Missing DB_USER env variable"
  exit 1
fi

if [[ ${DB_PASS} == "" ]]; then
  echo "ERROR: Missing DB_PASS env variable"
  exit 1
fi

if [[ ${DB_HOST} == "" ]]; then
  echo "ERROR: Missing DB_HOST env variable"
  exit 1
fi

echo -e "System Info:"
df -h | grep mysqldump

echo -e "Creating working directory ${BACKUP_STORAGE}/${DATE_BACKUP}"
mkdir -p ${BACKUP_STORAGE}/${DATE_BACKUP}
ls -lah ${BACKUP_STORAGE}/${DATE_BACKUP}

if [ "$ALL_DATABASES" = true ] ; then
  echo -e "\nDumping all database option: \n Databases: ${BACKUP_DATABASES}"
  mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --all-databases > ${BACKUP_STORAGE}/${DATE_BACKUP}/all_databases.sql
else
  echo -e "\nDumping specific databases option:"
  for db in $BACKUP_DATABASES; do
    if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
      echo -e "\n- Dumping database: $db"
      mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --databases ${db} > ${BACKUP_STORAGE}/${DATE_BACKUP}/${db}.sql
    fi
  done
fi

ls -lah ${BACKUP_STORAGE}/${DATE_BACKUP}