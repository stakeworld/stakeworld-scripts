#!/bin/bash
# STAKEWORLD 2022
# Make a backup of kusama and polkadot nodes key and network store
# Run this script in crontab

# Error handling
error() {
    echo "Error on line $1"
    echo "Exiting"
    exit 1
}

trap 'error $LINENO' ERR


# Setup variables
datadir="/home/polkadot"
workdir="/opt/stakeworld-scripts"
backupdir="/backup"
date=`date +%Y.%m.%d.%H.%M`
node=`hostname`

# Directories
mkdir -p $backupdir/$node
mkdir -p $workdir/var

# STDOUT to logfile
exec 1>>$workdir/var/backup.log

# START
echo `date` "Starting backup"
tar --exclude='paritydb' --exclude='db' -zcvf $backupdir/$node/keystore-backup.$date.tgz $datadir 2>/dev/null
tar -zcvf $backupdir/$node/etc-backup.$date.tgz /etc 2>/dev/null
