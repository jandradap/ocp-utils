#!/bin/bash

echo ".___  ___. ____    ____  _______.  ______      __      ";
echo "|   \/   | \   \  /   / /       | /  __  \    |  |     ";
echo "|  \  /  |  \   \/   / |   (----\`|  |  |  |   |  |     ";
echo "|  |\/|  |   \_    _/   \   \    |  |  |  |   |  |     ";
echo "|  |  |  |     |  | .----)   |   |  \`--'  '--.|  \`----.";
echo "|__|  |__|     |__| |_______/     \_____\_____|_______|";
echo "       _______   __    __  .___  ___. .______          ";
echo "      |       \ |  |  |  | |   \/   | |   _  \         ";
echo "      |  .--.  ||  |  |  | |  \  /  | |  |_)  |        ";
echo "      |  |  |  ||  |  |  | |  |\/|  | |   ___/         ";
echo "      |  '--'  ||  \`--'  | |  |  |  | |  |             ";
echo "      |_______/  \______/  |__|  |__| | _|             ";
echo "                                                       ";

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
BACKUP_DATABASES=${BACKUP_DATABASES:-${MYSQL_ENV_DB_NAME}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
ALL_DATABASES=${ALL_DATABASES}
IGNORE_DATABASE=${IGNORE_DATABASE}
BACKUP_STORAGE=${BACKUP_STORAGE}
BACKUP_STORAGE_PREFIX="/mysqldump"
DATE_BACKUP=$(date +%Y%m%d%H%M)
DELETE_OLD_BACKUPS=${DELETE_OLD_BACKUPS:-false}
MAX_BACKUP_DAYS=${MAX_BACKUP_DAYS:-7}
FIND_MAX_DEPTH=${FIND_MAX_DEPTH:-2}
MIN_MAX_DEPTH=${MIN_MAX_DEPTH:-1}

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

if [[ ${BACKUP_STORAGE} == "" ]]; then
  echo -e "\nERROR: Missing BACKUP_STORAGE env variable"
  exit 1
else {
  BACKUP_STORAGE="${BACKUP_STORAGE_PREFIX}/${BACKUP_STORAGE}"
  BACKUP_PATH="${BACKUP_STORAGE}/${DATE_BACKUP}"
}
fi

echo -e "\nSystem Info:"
df -h | grep mysqldump

echo -e "\n"
tree -L 3 -T "Backup" ${BACKUP_STORAGE}

if [ -d "${BACKUP_PATH}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_PATH} already exits."
  exit 1
else
  echo -e "\nCreating working directory ${BACKUP_PATH}"
  mkdir -p ${BACKUP_PATH}
  ls -lah ${BACKUP_PATH}

  if [ "$ALL_DATABASES" = true ] ; then
    echo -e "\nDumping all database option: \n Databases: ${BACKUP_DATABASES}"
    mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --all-databases > ${BACKUP_PATH}/all_databases.sql || exit 1
    sha1sum ${BACKUP_PATH}/all_databases.sql >> ${BACKUP_PATH}/checksums.txt
  else
    echo -e "\nDumping specific databases option:"
    for db in $BACKUP_DATABASES; do
      if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != _* ]] && [[ "$db" != "$IGNORE_DATABASE" ]]; then
        echo -e "\t- Dumping database: $db"
        mysqldump --user="${DB_USER}" --password="${DB_PASS}" --host="${DB_HOST}" --databases ${db} > ${BACKUP_PATH}/${db}.sql || exit 1
        sha1sum ${BACKUP_PATH}/${db}.sql >> ${BACKUP_PATH}/checksums.txt
      fi
    done
  fi

  echo -e "\nBackup list:"
  ls -lah ${BACKUP_PATH}

  echo -e "\nSha1sum:"
  cat ${BACKUP_PATH}/checksums.txt

  if [ "$DELETE_OLD_BACKUPS" = true ] ; then {
    echo -e "\nCleaning backups dir ${BACKUP_STORAGE} older backups than ${MAX_BACKUP_DAYS} days"
    ls -lah ${BACKUP_STORAGE}/
    find ${BACKUP_STORAGE} -maxdepth ${MIN_MAX_DEPTH} -mindepth ${MIN_MAX_DEPTH} -type d -mtime +${MAX_BACKUP_DAYS} -exec rm -r {} +
    echo -e "\nAfter clean:"
    ls -lah ${BACKUP_STORAGE}/
  }
  fi

fi
