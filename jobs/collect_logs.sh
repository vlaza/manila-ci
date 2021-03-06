#!/bin/bash


echo "Collecting logs"

set -x

source /home/jenkins-slave/runs/devstack_params.$ZUUL_UUID.manila.txt

if [ -z '$ZUUL_CHANGE' ] || [ -z '$ZUUL_PATCHSET' ]; then
    echo 'Missing parameters!'
    echo "ZUUL_CHANGE=$ZUUL_CHANGE"
    echo "ZUUL_PATCHSET=$ZUUL_PATCHSET"
    exit 1
fi

function ssh_cmd_logs_sv {
    local CMD=$1
    ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY logs@logs.openstack.tld $CMD
}

ssh -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP "/home/ubuntu/bin/collect_logs.sh $IS_DEBUG_JOB"

if [ "$IS_DEBUG_JOB" != "yes" ];then
    LOG_ARCHIVE_DIR="/srv/logs/manila/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE"
else
    TIMESTAMP=$(date +%d-%m-%Y_%H-%M)
    LOG_ARCHIVE_DIR="/srv/logs/debug/manila/$ZUUL_CHANGE/$ZUUL_PATCHSET/$JOB_TYPE/$TIMESTAMP"
fi

echo "Creating logs destination folder"
ssh_cmd_logs_sv "if [ ! -d $LOG_ARCHIVE_DIR ]; then mkdir -p $LOG_ARCHIVE_DIR; else rm -rf $LOG_ARCHIVE_DIR/*; fi"

echo "Downloading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $DEVSTACK_SSH_KEY ubuntu@$DEVSTACK_FLOATING_IP:/home/ubuntu/aggregate.tar.gz "aggregate-$NAME.tar.gz"

echo "GZIP:"
gzip -v9 $CONSOLE_LOG

echo "Uploading logs"
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY "aggregate-$NAME.tar.gz" logs@logs.openstack.tld:$LOG_ARCHIVE_DIR/aggregate-logs.tar.gz
scp -o "UserKnownHostsFile /dev/null" -o "StrictHostKeyChecking no" -i $LOGS_SSH_KEY $CONSOLE_LOG.gz logs@logs.openstack.tld:$LOG_ARCHIVE_DIR/console.log.gz && rm -f $CONSOLE_LOG*

echo "Extracting logs"
ssh_cmd_logs_sv "tar -xzf $LOG_ARCHIVE_DIR/aggregate-logs.tar.gz -C $LOG_ARCHIVE_DIR"

echo "Fixing permissions on all log files"
ssh_cmd_logs_sv "chmod a+rx -R $LOG_ARCHIVE_DIR"

set +x
