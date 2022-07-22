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
workdir="/home/polkadot"
backupdir="/backup"
date=`date +%Y.%m.%d.%H.%M`
node=`hostname`

mkdir -p $backupdir/$node

tar --exclude='paritydb' --exclude='db' -zcvf $backupdir/$node/keystore-backup.$date.tgz $workdir
tar -zcvf $backupdir/$node/etc-backup.$date.tgz /etc
