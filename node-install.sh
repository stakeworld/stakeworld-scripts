#!/bin/bash
# STAKEWORLD 2022
# Install a node

# Error handling
error() {
    echo "Error on line $1"
    echo "Exiting"
    exit 1
}

trap 'error $LINENO' ERR

# Init 
if ! which whiptail > /dev/null; then
   echo -e "Command whiptail not found! Install? (y/n) \c"
   read
   if "$REPLY" = "y"; then
      sudo apt install whiptail
   fi
fi

# Functions

function menu() { whiptail --menu "$@" 3>&1 1>&2 2>&3 ; }
function msg() { whiptail --msgbox "$@" 0 75; }
function input() { whiptail --inputbox "$@" 3>&1 1>&2 2>&3 ; }
function yesno() { whiptail --yesno "$@" 0 70 3>&1 1>&2 2>&3 ; }

function mainmenu() { 
	action=$(menu "STAKEWORLD polkadot/kusama node installer \n\nThis script can install a node, the startup scripts, firewall and optionally restore a snapshot. The installer creates a script which you can review before executing." 0 75 0 nodeinstall "Install a node" snapinstall "Restore a snapshot" "exit" "Exit installer") 
	$action
}

function nodeinstall {

# Start our script
cat << EOF >> $scriptdir/install.sh
#!/bin/bash
# created on $date

EOF

chain=$(menu "Which chain do you want to install" 0 75 0 polkadot "polkadot node" "ksmcc3" "kusama node" )
database=$(menu "Which database do you want to install" 0 75 0 paritydb "Paritydb (newer, quicker)" "rocksdb" "Rocksdb (more stable)" )
telemetry=$(menu "Which telemetry to use" 0 75 0 "telemetry.polkadot.io" "default telemetry" "telemetry-backend.w3f.community" "1000 validator telemetry" )
nodedir=$(menu "Where do you want to install" 0 75 0 "/home/polkadot/" " best for multi-node install" "/root/.local/share/polkadot/" " default location" )
nodename=$(input "How do you want to name your node. This will be used in the systemctl script and in the homedirectory." 0 70 "mynode" )
nodenumber=$(menu "Depending on hardware and network it is possible to install extra nodes, official advise is one node per server. For one node choose 01, for the second 02, etc" 0 75 0 "00" "first node" "01" "Second node" "03" "Third node" )

cat << EOF >> $scriptdir/$nodename-$nodenumber.service
[Unit]
Description=$chain $nodename-$nodenumber
After=network.target
Documentation=https://github.com/paritytech/polkadot
StartLimitIntervalSec=200
StartLimitBurst=2

[Service]
ExecStart=/usr/bin/polkadot --chain $chain --name $nodename-$nodenumber --validator --pruning 1000 --port 303$nodenumber --rpc-port 99$nodenumber --ws-port 98$nodenumber --prometheus-port 96$nodenumber --prometheus-external --base-path $nodedir/$nodename-$nodenumber --database $database --telemetry-url 'wss://$telemetry/submit 1' 
User=polkadot
Group=polkadot
Restart=always
RestartSec=30
CapabilityBoundingSet=
LockPersonality=true
NoNewPrivileges=true
PrivateDevices=true
PrivateMounts=true
PrivateTmp=true
PrivateUsers=true
ProtectClock=true
ProtectControlGroups=true
ProtectHostname=true
ProtectKernelModules=true
ProtectKernelTunables=true
ProtectSystem=strict
RemoveIPC=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_NETLINK AF_UNIX
RestrictNamespaces=true
RestrictSUIDSGID=true
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@clock @module @mount @reboot @swap @privileged
UMask=0027

[Install]
WantedBy=multi-user.target
EOF

if (yesno "You want to install the polkadot binary via apt?"); then
cat << EOF >> $scriptdir/install.sh
# Import the security@parity.io GPG key
gpg --recv-keys --keyserver hkps://keys.mailvelope.com 9D4B2B6EB8F97156D19669A9FF0812D491B96798
gpg --export 9D4B2B6EB8F97156D19669A9FF0812D491B96798 > /usr/share/keyrings/parity.gpg
# Add the Parity repository and update the package index
echo 'deb [signed-by=/usr/share/keyrings/parity.gpg] https://releases.parity.io/deb release main' > /etc/apt/sources.list.d/parity.list
apt update
# Install the `parity-keyring` package - This will ensure the GPG key
# used by APT remains up-to-date
apt install parity-keyring
# Install polkadot
apt install polkadot
EOF
fi

cat << EOF >> $scriptdir/install.sh
# Install systemctl script
cp $scriptdir/$nodename-$nodenumber.service /etc/systemd/system
# Start/stop polkadot to create directory structure
systemctl daemon-reload
systemctl start $nodename-$nodenumber
sleep 5
systemctl stop $nodename-$nodenumber
systemctl enable $nodename-$nodenumber
EOF

# Network
if (yesno "You want to install the firewall"); then
cat << EOF >> $scriptdir/install.sh
# firewall
apt install ufw
ufw allow openssh
ufw enable
ufw allow from any port 30300:30399 proto tcp
ufw status
EOF
fi

# Snapshot
if (yesno "You want to restore a snapshot?"); then
cat << EOF >> $scriptdir/install.sh
# Installing s snapshot
curl -o - -L http://snapshot.stakeworld.nl/$database-$chain.lz4 | lz4 -c -d - | tar -x -C $nodedir/$nodename-$nodenumber/chains/$chain
EOF
fi

# Start process
cat << EOF >> $scriptdir/install.sh
# Start the process
systemctl start $nodename-$nodenumber
# Endnote
echo "If everything is well the node is running now and should be visible from https://$telemetry (tip: start typing to search for your node)"
echo "The script is located in $scriptdir"
echo "For more information see https://stakeworld.nl" 
EOF

}

function snapinstall {

chain=$(menu "Which chain do you want to install" 0 75 0 polkadot "polkadot node" "ksmcc3" "kusama node" )
database=$(menu "Which database do you want to install" 0 75 0 paritydb "Paritydb (newer, quicker)" "rocksdb" "Rocksdb (more stable)" )

snaptargets=`find /home/polkadot /home/polkadot2 /root/.local/share/ -maxdepth 1 -mindepth 1 -type d \( ! -iname ".*" \) -printf "%p -\n" 2> /dev/null`
nodedir=$(menu "Where do you want to install" 0 75 0 $snaptargets )

# Make our script
cat << EOF >> $scriptdir/install.sh
#!/bin/bash
# created on $date

# Installing s snapshot
mkdir -p $nodedir/chains/$chain
curl -o - -L http://snapshot.stakeworld.nl/$database-$chain.lz4 | lz4 -c -d - | tar -x -C $nodedir/chains/$chain
EOF

}

# Main logic
scriptdir="/tmp/node-install"
if [ -d $scriptdir ] ; then
	mv /tmp/node-install /tmp/node-install.$(date +%F.%R)
fi
	
mkdir -p $scriptdir
touch $scriptdir/install.sh
chmod +x $scriptdir/install.sh
servername=`hostname`
date=`date`

mainmenu

nano $scriptdir/install.sh

if (yesno "You want to proceed and runt the script?"); then
$scriptdir/install.sh
fi

echo "Script finished"

