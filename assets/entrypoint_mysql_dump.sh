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
  echo "Missing DB_USER env variable"
  exit 1
fi

if [[ ${DB_PASS} == "" ]]; then
  echo "Missing DB_PASS env variable"
  exit 1
fi

if [[ ${DB_HOST} == "" ]]; then
  echo "Missing DB_HOST env variable"
  exit 1
fi

mkdir -p $BACKUP_STORAGE/$DATE_BACKUP


if [ "$ALL_DATABASES" = true ] ; then
  mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --all-databases > ${BACKUP_STORAGE}/$DATE_BACKUP/all_databases.sql
else
  for db in $BACKUP_DATABASES; do
      if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
          echo "Dumping database: $db"
          mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --databases $db > ${BACKUP_STORAGE}/$DATE_BACKUP/$db.sql
      fi
  done
fi