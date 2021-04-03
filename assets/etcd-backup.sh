#!/bin/bash
# FILE: etcd-backup.sh
# AUTHOR: Jorge Andrada
# PURPOSE: take the etcd backup of an openshift 4.x cluster connecting to a "random" master

## FUNCTIONS
# f_log: function that will print output with a simple log format
function f_log ()
{
  OUTPUT_STRING="$1"
  echo -e "$(date '+%Y/%m/%d %H:%m')- $OUTPUT_STRING"
}

# function that log the exit code of the script
function f_exit ()
{
  EXIT_CODE="$1"
  f_log "INFO: Job ${HOSTNAME} exited with exit code ${EXIT_CODE}"
  exit ${EXIT_CODE}
}

# Show environemnt variables passed and set default values
# env | grep "^KUP_"
[[ -z "$RETENTION_DAYS" ]] && RETENTION_DAYS="365"
[[ -z "$LOGIN_USER" ]] && LOGIN_USER="core"

MASTER_NODE_LIST=""
MASTER_NODE=""
BACKUP_DONE=1
SSH_OPTIONS="-i $CLUSTER_NODE_SSH_KEY -o StrictHostKeyChecking=no"
DESTINATION_PATH="/mnt/etcd-backup"
CLUSTER_NODE_SSH_KEY="/tmp/cluster-node-ssh-key"
MASTER_NODE_BACKUP_DESTINATION_PATH="/home/core/assets/backup"
LOGIN_SECRET_PATH="/var/run/secrets/kubernetes.io/serviceaccount"
LOGIN_SECRET_TOKEN_PATH="$LOGIN_SECRET_PATH/token"
LOGIN_CA_PATH="$LOGIN_SECRET_PATH/ca.crt"

f_log "INFO: Job ${HOSTNAME} for ETCD Backup started."
# check if mount path to the persistent volume claim exists
if [[ ! -d ${DESTINATION_PATH} ]]
then
  f_log "ERROR: ${DESTINATION_PATH} is not a directory or not mounted."
  f_exit 10
fi
# clean older backup
f_log "INFO: Cleaning backup older then ${RETENTION_DAYS} days"
find ${DESTINATION_PATH} -xdev -type f -mtime "+$RETENTION_DAYS" -delete
# check if kubectl command is present
OC_PATH=$(which oc 2>/dev/null)
if [[ $? -ne 0 ]]
then
  f_log -e "ERROR: Can't find kubectl command in $PATH, check the image used."
  f_exit 20
fi
# check if the cronjob pod is already connected to the cluster
# if not logged kubectl version command will time out by asking user and password
timeout 30 $OC_PATH version &>/dev/null
if [[ $? -eq 0 ]]
then
  f_log "INFO: Pod $HOSTNAME is already logged to cluster."
else
  # start login by retrieving serviceaccount token and certificates
  LOGIN_TOKEN=$(cat $LOGIN_SECRET_TOKEN_PATH 2>/dev/null)
  # login to the cluster
  timeout 30 $OC_PATH login $API_SERVER --token="$LOGIN_TOKEN" --certificate-authority="$LOGIN_CA_PATH"
  # re-check login
  timeout 30 $OC_PATH version &>/dev/null
  if [[ $? -ne 0 ]]
  then
    f_log "ERROR: Can't login on the cluster at $API_SERVER, check service-account and secrets"
    f_exit 21
  fi
fi
# check if serviceaccount can list nodes
($OC_PATH auth can-i list nodes 2>/dev/null)
if [[ $? -ne 0 ]]
then
  f_log "ERROR: Service account can't list nodes. Check if etcd-backup-view-nodes role is configured and binded to etcd-backup-sa"
fi
# check if cluster master node are all ready
NOT_READY_NODES=$($OC_PATH get nodes -l "node-role.kubernetes.io/master=" | grep -v '^NAME ' | grep -v ' Ready' | wc -l 2>/dev/null)
if [[ "$NOT_READY_NODES" -ne 0 ]]
then
  f_log "ERROR: Some master nodes aren't ready. Check cluster health."
  f_exit 22
fi
# retrieve master nodes in random order to make a simple round robin on the nodes
f_log "INFO: Master nodes are all OK, start backup on random node."

echo -e "\nCreando backup ETCD..."
mkdir -p etcd
healthy=$($OC_PATH get etcd -o=jsonpath='{range .items[0].status.conditions[?(@.type=="EtcdMembersAvailable")]}{.message}{"\n"}')
if [ "$healthy" != "3 members are available" ]; then
  echo "check to see if something is broken"
  exit 1
fi
#if [ ! -d ./backup ]; then mkdir ./backup; fi
#backupdir=$(mktemp -dt "backup.XXXXXXXX" --tmpdir=./backup)
# get etcd's node name
ETCD_NODE=$($OC_PATH get pods -n openshift-etcd -l app=etcd -o=jsonpath='{.items[0].spec.nodeName}')
# use ssh to remove old backup, take new backup, copy it off.
ssh -n "${SSH_OPTIONS}" "core@${ETCD_NODE}" 'sudo -E rm -rf ./assets/backup/*' | exit 1
ssh -n "${SSH_OPTIONS}" "core@${ETCD_NODE}" 'sudo -E /usr/local/bin/cluster-backup.sh ./assets/backup' | exit 1
ssh -n "${SSH_OPTIONS}" "core@${ETCD_NODE}" 'sudo -E chmod 644 ./assets/backup/*' | exit 1
scp "${SSH_OPTIONS}" "core@${ETCD_NODE}":/home/core/assets/backup/* "${DESTINATION_PATH}" | exit 1

ls -lh "${DESTINATION_PATH}"