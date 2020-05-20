#!/bin/bash

echo " _______  __          ___           _______.___________.__    ______ ";
echo "|   ____||  |        /   \         /       |           |  |  /      |";
echo "|  |__   |  |       /  ^  \       |   (----\`---|  |----|  | |  ,----'";
echo "|   __|  |  |      /  /_\  \       \   \       |  |    |  | |  |     ";
echo "|  |____ |  \`----./  _____  \  .----)   |      |  |    |  | |  \`----.";
echo "|_______||_______/__/     \__\ |_______/       |__|    |__|  \______|";
echo "             _______   __    __  .___  ___. .______                  ";
echo "            |       \ |  |  |  | |   \/   | |   _  \                 ";
echo "            |  .--.  ||  |  |  | |  \  /  | |  |_)  |                ";
echo "            |  |  |  ||  |  |  | |  |\/|  | |   ___/                 ";
echo "            |  '--'  ||  \`--'  | |  |  |  | |  |                     ";
echo "            |_______/  \______/  |__|  |__| | _|                     ";
echo "                                                                     ";

BACKUP_STORAGE=${BACKUP_STORAGE}
BACKUP_STORAGE_PREFIX="/rsyncdump"
DATE_BACKUP=$(date +%Y%m%d%H%M)
DELETE_OLD_BACKUPS=${DELETE_OLD_BACKUPS:-false}
MAX_BACKUP_DAYS=${MAX_BACKUP_DAYS:-7}
FIND_MAX_DEPTH=${FIND_MAX_DEPTH:-2}
MIN_MAX_DEPTH=${MIN_MAX_DEPTH:-1}
ORIGIN_VOLUME="/rsyncori"
SLEEP_TIME_CURL=${SLEEP_TIME_CURL:-30}
NUM_CHECK_ATTEMPS=${NUM_CHECK_ATTEMPS:-10}
ELASTIC_SVC_NAME=${ELASTIC_SVC_NAME:-elasticsearch}
ELASTIC_SVC_PORT=${ELASTIC_SVC_PORT:-9200}
ELASTIC_BCK_FOLDER_NAME=${ELASTIC_BCK_FOLDER_NAME:-${ELASTIC_BCK_FOLDER_NAME}}

if [[ ${ORIGIN_VOLUME} == "" ]]; then
  echo -e "\nERROR: Missing ORIGIN_VOLUME env variable"
  exit 1
fi

if [[ ${BACKUP_STORAGE} == "" ]]; then
  echo -e "\nERROR: Missing BACKUP_STORAGE env variable"
  exit 1
else {
  BACKUP_STORAGE="${BACKUP_STORAGE_PREFIX}/${BACKUP_STORAGE}"
  BACKUP_PATH="${BACKUP_STORAGE}/${DATE_BACKUP}"
  mkdir -p ${BACKUP_STORAGE}
}
fi

echo -e "\nSystem Info:"
df -h | grep "rsyncdump\|rsyncori"

tree -L 2 -T "Origen" /rsyncori
echo -e "\n"
tree -L 3 -T "Backup" ${BACKUP_STORAGE}

if [ -d "${BACKUP_PATH}" ]; then
  echo -e "\nERROR: Directory ${BACKUP_PATH} already exits."
  exit 1
else {
  if [ -z "$(ls -A /rsyncori)" ]; then
    echo -e "\nThere are no snapshots."
  else
    echo -e "\nDeleting old snapshots..."
    rm -rf /rsyncori/* &
    BACK_PID=$!
    wait $BACK_PID
    ls -lh /rsyncori
  fi

  echo -e "\nSnapshot creation launched..."
  curl -s -X PUT "${ELASTIC_SVC_NAME}:${ELASTIC_SVC_PORT}/_snapshot/${ELASTIC_BCK_FOLDER_NAME}/snapshot?wait_for_completion=false" | jq "."
  echo -e "\nChecking snapshot..."

  NUM_CHECK=0
  while [ "$CHECK_SNAP" != "SUCCESS" ]
  do
    echo -e "\tCheck numer ${NUM_CHECK}, waiting until ${NUM_CHECK_ATTEMPS} x ${SLEEP_TIME_CURL}..."
    if [ "$NUM_CHECK" -gt "$NUM_CHECK_ATTEMPS" ]; then
      echo -e "\nERROR: number of checks exceeded"
      exit 1
    fi
    sleep $SLEEP_TIME_CURL
    let "NUM_CHECK+=1"
    CHECK_SNAP=$(curl -s -X GET "${ELASTIC_SVC_NAME}:${ELASTIC_SVC_PORT}/_snapshot/${ELASTIC_BCK_FOLDER_NAME}/snapshot" | jq ".snapshots[0].state" | sed "s/\"//g")
  done

  
  if [ "$CHECK_SNAP" == "SUCCESS" ]; then {
      echo -e "\nSnapshot: ${CHECK_SNAP}"
      du -hs /rsyncori
      ls -lh /rsyncori
      echo -e "\nCreating working directory ${BACKUP_PATH}"
      mkdir -p ${BACKUP_PATH}
      ls -lah ${BACKUP_PATH}

      echo -e "\nLaunch RSYNC temp..."
      mkdir -p ${BACKUP_PATH}/temp
      rsync -axHAX ${ORIGIN_VOLUME}/ ${BACKUP_PATH}/temp/ || exit 1

      echo -e "\nList Rsync output:"
      ls -lah ${BACKUP_PATH}/temp/

      echo -e "\nCompress backup path and delete temp:"
      cd ${BACKUP_PATH}/temp || exit 1
      tar -czf backup_${DATE_BACKUP}.tar.gz *
      mv backup_${DATE_BACKUP}.tar.gz ../
      cd ..
      rm -rf ${BACKUP_PATH}/temp
      sha1sum backup_${DATE_BACKUP}.tar.gz >> checksums.txt

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
    } else {
      echo -e "\nERROR: Error creating snapshot or check time exceeded."
      exit 1
    }
    fi
  }
fi
