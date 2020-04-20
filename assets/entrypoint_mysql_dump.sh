#!/bin/bash

echo ".___  ___. ____    ____  _______.  ______      __          _______   __    __  .___  ___. .______   ";
echo "|   \/   | \   \  /   / /       | /  __  \    |  |        |       \ |  |  |  | |   \/   | |   _  \  ";
echo "|  \  /  |  \   \/   / |   (----\`|  |  |  |   |  |        |  .--.  ||  |  |  | |  \  /  | |  |_)  | ";
echo "|  |\/|  |   \_    _/   \   \    |  |  |  |   |  |        |  |  |  ||  |  |  | |  |\/|  | |   ___/  ";
echo "|  |  |  |     |  | .----)   |   |  \`--'  '--.|  \`----.   |  '--'  ||  \`--'  | |  |  |  | |  |      ";
echo "|__|  |__|     |__| |_______/     \_____\_____|_______|   |_______/  \______/  |__|  |__| | _|      ";
echo "                                                                                                    ";

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
BACKUP_DATABASES=${BACKUP_DATABASES:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
IGNORE_DATABASE=${IGNORE_DATABASE}
BACKUP_STORAGE=${BACKUP_STORAGE:-/tmp}
DATE_BACKUP=$(date +%Y%m%d)

if [[ ${DB_USER} == "" ]]; then
  echo -e "\nERROR: Missing DB_USER env variable"
  exit 1
fi

if [[ ${DB_PASS} == "" ]]; then
  echo -e "\nERROR: Missing DB_PASS env variable"
  exit 1
fi

if [[ ${DB_HOST} == "" ]]; then
  echo -e "\nERROR: Missing DB_HOST env variable"
  exit 1
fi

echo -e "\nSystem Info:"
df -h | grep mysqldump

if [ -d "${BACKUP_STORAGE}/${DATE_BACKUP}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_STORAGE}/${DATE_BACKUP} already exits."
else
  echo -e "\nCreating working directory ${BACKUP_STORAGE}/${DATE_BACKUP}"
  mkdir -p ${BACKUP_STORAGE}/${DATE_BACKUP}
  ls -lah ${BACKUP_STORAGE}/${DATE_BACKUP}

  if [ "$ALL_DATABASES" = true ] ; then
    echo -e "\nDumping all database option: \n Databases: ${BACKUP_DATABASES}"
    mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --all-databases > ${BACKUP_STORAGE}/${DATE_BACKUP}/all_databases.sql
  else
    echo -e "\nDumping specific databases option:"
    for db in $BACKUP_DATABASES; do
      if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo -e "\t- Dumping database: $db"
        mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --databases ${db} > ${BACKUP_STORAGE}/${DATE_BACKUP}/${db}.sql
      fi
    done
  fi

  echo -e "\nBackup list:"
  ls -lah ${BACKUP_STORAGE}/${DATE_BACKUP}

  echo -e "\nCreating sha1sum:"
  cd ${BACKUP_STORAGE}/${DATE_BACKUP} ; 
  for i in *.*; do sha1sum "$i" ; done) >> checksums.txt
  cat checksums.txt

fi
