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
BACKUP_PATH="${BACKUP_STORAGE}/${DATE_BACKUP}"

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

if [ -d "${BACKUP_PATH}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_PATH} already exits."
  exit 1
else
  echo -e "\nCreating working directory ${BACKUP_PATH}"
  mkdir -p ${BACKUP_PATH}
  ls -lah ${BACKUP_PATH}

  if [ "$ALL_DATABASES" = true ] ; then
    echo -e "\nDumping all database option: \n Databases: ${BACKUP_DATABASES}"
    mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --all-databases > ${BACKUP_PATH}/all_databases.sql
    sha1sum ${BACKUP_PATH}/all_databases.sql >> ${BACKUP_PATH}/checksums.txt
  else
    echo -e "\nDumping specific databases option:"
    for db in $BACKUP_DATABASES; do
      if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo -e "\t- Dumping database: $db"
        mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --databases ${db} > ${BACKUP_PATH}/${db}.sql
        sha1sum ${BACKUP_PATH}/${db}.sql >> ${BACKUP_PATH}/checksums.txt
      fi
    done
  fi

  echo -e "\nBackup list:"
  ls -lah ${BACKUP_PATH}

  echo -e "\nSha1sum:"
  cat ${BACKUP_PATH}/checksums.txt

fi
