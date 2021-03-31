#!/bin/bash
# FILE: etcd-backup.sh
# AUTHOR: Simone Mossi
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
KUBECTL_PATH=$(which kubectl 2>/dev/null)
if [[ $? -ne 0 ]]
then
  f_log -e "ERROR: Can't find kubectl command in $PATH, check the image used."
  f_exit 20
fi
# check if the cronjob pod is already connected to the cluster
# if not logged kubectl version command will time out by asking user and password
timeout 30 $KUBECTL_PATH version &>/dev/null
if [[ $? -eq 0 ]]
then
  f_log "INFO: Pod $HOSTNAME is already logged to cluster."
else
  # start login by retrieving serviceaccount token and certificates
  LOGIN_TOKEN=$(cat $LOGIN_SECRET_TOKEN_PATH 2>/dev/null)
  # login to the cluster
  timeout 30 $KUBECTL_PATH login $KUP_API_SERVER --token="$LOGIN_TOKEN" --certificate-authority="$LOGIN_CA_PATH"
  # re-check login
  timeout 30 $KUBECTL_PATH version &>/dev/null
  if [[ $? -ne 0 ]]
  then
    f_log "ERROR: Can't login on the cluster at $KUBE_API_SERVER, check service-account and secrets"
    f_exit 21
  fi
fi
# check if serviceaccount can list nodes
($KUBECTL_PATH auth can-i list nodes 2>/dev/null)
if [[ $? -ne 0 ]]
then
  f_log "ERROR: Service account can't list nodes. Check if etcd-backup-view-nodes role is configured and binded to etcd-backup-sa"
fi
# check if cluster master node are all ready
NOT_READY_NODES=$($KUBECTL_PATH get nodes -l "node-role.kubernetes.io/master=" | grep -v '^NAME ' | grep -v ' Ready' | wc -l 2>/dev/null)
if [[ "$NOT_READY_NODES" -ne 0 ]]
then
  f_log "ERROR: Some master nodes aren't ready. Check cluster health."
  f_exit 22
fi
# retrieve master nodes in random order to make a simple round robin on the nodes
f_log "INFO: Master nodes are all OK, start backup on random node."
MASTER_NODE_LIST=$($KUBECTL_PATH get nodes -l "node-role.kubernetes.io/master=" -o name | cut -d '/' -f 2 | tr '\n' ' ' 2>/dev/null)
for MASTER_NODE in $MASTER_NODE_LIST
do
  # testing if master node is reachable
  f_log "INFO: Trying to backup master node $MASTER_NODE."
  (timeout 30 ssh -n $SSH_OPTIONS core@$MASTER_NODE "echo 'Check'" &>/dev/null)
  if [[ $? -ne 0 ]]
  then
    # if not, skip the node and choose the next node
    f_log "WARNING: Master node $MASTER_NODE seems to be unreachable! Trying next node."
    continue
  fi
  # remove the old backup file if present
  ssh -n $SSH_OPTIONS core@$MASTER_NODE "sudo rm -rf $MASTER_NODE_BACKUP_DESTINATION_PATH/*"
  # launch the openshift cluster backup script present on the nodes
  ssh -n $SSH_OPTIONS core@$MASTER_NODE "sudo /usr/local/bin/cluster-backup.sh $MASTER_NODE_BACKUP_DESTINATION_PATH"
  if [[ $? -ne 0 ]]
  then
    f_log "WARNING: Can't take backup on $MASTER_NODE, trying another master node"
    continue
  fi
  # create the tar archive name with timestamp
  BACKUP_ARCHIVE_DATE=$(date +%Y%m%d_%H%M%S 2>/dev/null)
  BACKUP_ARCHIVE_NAME="cluster-backup_$BACKUP_ARCHIVE_DATE.tar.gz"
  BACKUP_ARCHIVE_FULL_PATH="$MASTER_NODE_BACKUP_DESTINATION_PATH/$BACKUP_ARCHIVE_NAME"
  f_log "INFO: Creating backup archive $BACKUP_ARCHIVE_FULL_PATH"
  # creating the tar.gz archive and delete the original archived files
  ssh -n $SSH_OPTIONS core@$MASTER_NODE "sudo tar -czf $BACKUP_ARCHIVE_FULL_PATH $MASTER_NODE_BACKUP_DESTINATION_PATH/* --remove-files"
  if [[ $? -ne 0 ]]
  then
    f_log "WARNING: There was a problem in the tar process, skipping to next node."
    continue
  fi
  # copy the archive from the master node to the persistent volume claim
  f_log "INFO: Copy backup archive $BACKUP_ARCHIVE_NAME to ${DESTINATION_PATH}"
  scp $SSH_OPTIONS core@$MASTER_NODE:$BACKUP_ARCHIVE_FULL_PATH ${DESTINATION_PATH}
  if [[ $? -eq 0 ]]
  then
    ssh -n $SSH_OPTIONS core@$MASTER_NODE "sudo rm -f $BACKUP_ARCHIVE_FULL_PATH"
    f_log "INFO: Archive copied on ${DESTINATION_PATH}/$BACKUP_ARCHIVE_NAME"
    # set the backup flag to 0 to inform success
    BACKUP_DONE=0
    break
  fi
  f_log "WARNING: Problem on taking the backup from $MASTER_NODE, trying from another master"
done
if [[ $BACKUP_DONE -eq 0 ]]
then
  f_log "INFO: Backup succesfully done, backup file is in $OCP4_BACKUPPER_DESTINATION_PATH"
  f_exit 0
fi
f_log "ERROR: Can't take a backup on any master node in $MASTER_NODE_LIST"
f_exit 30
