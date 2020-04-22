#!/bin/bash

echo ".______          ___________    ____ .__   __.   ______ ";
echo "|   _  \        /       \   \  /   / |  \ |  |  /      |";
echo "|  |_)  |      |   (----\`\   \/   /  |   \|  | |  ,----'";
echo "|      /        \   \     \_    _/   |  . \`  | |  |     ";
echo "|  |\  \----.----)   |      |  |     |  |\   | |  \`----.";
echo "| _| \`._____|_______/       |__|     |__| \__|  \______|";
echo "          _______   __    __  .___  ___. .______        ";
echo "         |       \ |  |  |  | |   \/   | |   _  \       ";
echo "         |  .--.  ||  |  |  | |  \  /  | |  |_)  |      ";
echo "         |  |  |  ||  |  |  | |  |\/|  | |   ___/       ";
echo "         |  '--'  ||  \`--'  | |  |  |  | |  |           ";
echo "         |_______/  \______/  |__|  |__| | _|           ";
echo "                                                        ";

BACKUP_STORAGE=${BACKUP_STORAGE:-/tmp}
DATE_BACKUP=$(date +%Y%m%d%H%M)
BACKUP_PATH="${BACKUP_STORAGE}/${DATE_BACKUP}"
DELETE_OLD_BACKUPS=${DELETE_OLD_BACKUPS:-false}
MAX_BACKUP_DAYS=${MAX_BACKUP_DAYS:-7}
FIND_MAX_DEPTH=${FIND_MAX_DEPTH:-2}
MIN_MAX_DEPTH=${MIN_MAX_DEPTH:-1}
ORIGIN_VOLUME="/rsyncori"

if [[ ${PATHS_TO_BACKUP} == "" ]]; then
  echo -e "\nERROR: Missing PATHS_TO_BACKUP env variable"
  exit 1
fi

if [[ ${ORIGIN_VOLUME} == "" ]]; then
  echo -e "\nERROR: Missing ORIGIN_VOLUME env variable"
  exit 1
fi

echo -e "\nSystem Info:"
df -h | grep rsyncdump

if [ -d "${BACKUP_PATH}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_PATH} already exits."
  exit 1
else
  echo -e "\nCreating working directory ${BACKUP_PATH}"
  mkdir -p ${BACKUP_PATH}
  ls -lah ${BACKUP_PATH}

  echo -e "\nLaunch RSYNC temp..."
  mkdir -p ${BACKUP_PATH}/temp
  PATHS_TO_BACKUP=$(echo "${PATHS_TO_BACKUP}" | sed "s: : ${ORIGIN_VOLUME}:g")
  rsync -axHAX ${ORIGIN_VOLUME}/${PATHS_TO_BACKUP} ${BACKUP_PATH}/temp || exit 1

  echo -e "\nList Rsync output:"
  ls -lah ${BACKUP_PATH}/temp/

  echo -e "\nCompress backup path and delete temp:"
  cd ${PATHS_TO_BACKUP}/temp
  tar -czf backup_${DATE_BACKUP}.tar.gz *
  mv backup_${DATE_BACKUP}.tar.gz ../
  rm -rf ${BACKUP_PATH}/temp

  echo -e "\nBackup list:"
  ls -lah ${BACKUP_PATH}

  echo -e "\nSha1sum:"
  cat ${BACKUP_PATH}/checksums.txt

  if [ "$DELETE_OLD_BACKUPS" = true ] ; then {
    echo -e "\nCleaning backups dir ${BACKUP_PATH} older backups than ${MAX_BACKUP_DAYS} days"
    ls -lah ${BACKUP_STORAGE}/
    find ${BACKUP_STORAGE} -maxdepth ${MIN_MAX_DEPTH} -mindepth ${MIN_MAX_DEPTH} -type d -mtime +${MAX_BACKUP_DAYS} -exec rm -r {} +
    echo -e "\nAfter clean:"
    ls -lah ${BACKUP_STORAGE}/
  }
  fi

fi
