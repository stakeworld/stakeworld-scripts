# STAKEWORLD.nl scripts

Scripts focussed on running a polkadot/kusama node. All written in bash.

## clone repo

You can run it in /opt or any location you like

```
cd /opt
git clone git@github.com:stakeworld/stakeworld-scripts.git
```

## include path in profile
```
echo 'PATH=$PATH:~/opt/stakeworld-scripts/' >> ~/.profile
```

## included scripts
* node-install.sh: a polkadot/kusama node and snapshot installer.
* keystore-backup.sh: make a backup of the polkadot instances excluding the database, so the keystore and network keys. Also backup the /etc directory. Preferably mount an remote backup storage or export backups to remote storage.
