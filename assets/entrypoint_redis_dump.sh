#!/bin/bash

echo ".___  ___.   ______   .__   __.   _______   ______    _______  .______   ";
echo "|   \/   |  /  __  \  |  \ |  |  /  _____| /  __  \  |       \ |   _  \  ";
echo "|  \  /  | |  |  |  | |   \|  | |  |  __  |  |  |  | |  .--.  ||  |_)  | ";
echo "|  |\/|  | |  |  |  | |  . \`  | |  | |_ | |  |  |  | |  |  |  ||   _  <  ";
echo "|  |  |  | |  \`--'  | |  |\   | |  |__| | |  \`--'  | |  '--'  ||  |_)  | ";
echo "|__|  |__|  \______/  |__| \__|  \______|  \______/  |_______/ |______/  ";
echo "                _______   __    __  .___  ___. .______                   ";
echo "               |       \ |  |  |  | |   \/   | |   _  \                  ";
echo "               |  .--.  ||  |  |  | |  \  /  | |  |_)  |                 ";
echo "               |  |  |  ||  |  |  | |  |\/|  | |   ___/                  ";
echo "               |  '--'  ||  \`--'  | |  |  |  | |  |                      ";
echo "               |_______/  \______/  |__|  |__| | _|                      ";
echo "                                                                         ";

DB_USER=${DB_USER:-${MYSQL_ENV_DB_USER}}
DB_PASS=${DB_PASS:-${MYSQL_ENV_DB_PASS}}
DB_HOST=${DB_HOST:-${MYSQL_ENV_DB_HOST}}
DB_PORT=${DB_PORT:-6379}
RDB_FILE=${RDB_FILE:-dump.rdb}
BACKUP_STORAGE=${BACKUP_STORAGE}
BACKUP_STORAGE_PREFIX="/redisdump"
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
df -h | grep redisdump

echo -e "\n"
tree -L 3 -T "Backup" ${BACKUP_STORAGE}

if [ -d "${BACKUP_PATH}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_PATH} already exits."
  exit 1
else
  echo -e "\nCreating working directory ${BACKUP_PATH}"
  mkdir -p ${BACKUP_PATH}
  ls -lah ${BACKUP_PATH}

  echo -e "\nTesting Redis connection:"
  redis-cli -h "${DB_HOST}" -p "${DB_PORT}" -a "${DB_PASS}" ping || exit 1
  echo -e "\nForce dump cache to file and wait ${WAIT_SAVE_RDB} sec:"
  redis-cli -h "${DB_HOST}" -p "${DB_PORT}" -a "${DB_PASS}" save || exit 1
  sleep ${WAIT_SAVE_RDB}
  echo -e "\nTDownload ${RDB_FILE}:"
  
  cd ${BACKUP_PATH}/
  redis-cli -h "${DB_HOST}" -p "${DB_PORT}" -a "${DB_PASS}" --rdb "${RDB_FILE}" || exit 1

  find ${BACKUP_PATH} -type f -print0  | xargs -0 sha1sum >> ${BACKUP_PATH}/checksums.txt

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
