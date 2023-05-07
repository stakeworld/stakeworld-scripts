#!/bin/bash
# STAKEWORLD 2023
# Install a node

# Init 
if ! which whiptail > /dev/null; then
   echo -e "Command whiptail not found! Install? (y/n) \c"
   read
   if "$REPLY" = "y"; then
      sudo apt install whiptail
   fi
fi

# Functions
export NEWT_COLORS='root=,blue'

function menu() { whiptail --menu "$@" 3>&1 1>&2 2>&3 ; }
function msg() { whiptail --msgbox "$@" 0 75; }
function input() { whiptail --inputbox "$@" 3>&1 1>&2 2>&3 ; }
function yesno() { whiptail --yesno "$@" 0 70 3>&1 1>&2 2>&3 ; }


# Init script
scriptdir="/tmp/node-install"
if [ -d $scriptdir ] ; then
	mv /tmp/node-install /tmp/node-install.$(date +%F.%R)
fi
	
mkdir -p $scriptdir
touch $scriptdir/install.sh
chmod +x $scriptdir/install.sh
touch $scriptdir/snapshot.sh
chmod +x $scriptdir/snapshot.sh
servername=`hostname`
date=`date`

# Start our script
cat << EOF >> $scriptdir/install.sh
#!/bin/bash
# created on $date

EOF

# Install binary
if (yesno "You want to install the polkadot binary via apt?"); then
cat << EOF >> $scriptdir/install.sh
# Import the security@parity.io GPG key
apt -y install gpg
gpg --recv-keys --keyserver hkps://keys.mailvelope.com 9D4B2B6EB8F97156D19669A9FF0812D491B96798
gpg --export 9D4B2B6EB8F97156D19669A9FF0812D491B96798 > /usr/share/keyrings/parity.gpg
# Add the Parity repository and update the package index
echo 'deb [signed-by=/usr/share/keyrings/parity.gpg] https://releases.parity.io/deb release main' > /etc/apt/sources.list.d/parity.list
apt update
apt -y install parity-keyring
# Install polkadot
apt -y install polkadot
EOF
fi

# Firewall
if (yesno "You want to install the firewall"); then
cat << EOF >> $scriptdir/install.sh
# firewall
echo "Enabling the firewall"
apt -y install ufw
ufw allow openssh
ufw --force enable
ufw allow from any port 30300:30399 proto tcp
ufw allow 30300:30399/tcp
ufw logging off
ufw status
EOF
fi

if (yesno "You want to install a service file? Default is warp sync, or you can choose a snapshot"); then
chain=$(menu "Which chain do you want to install" 0 75 0 polkadot "polkadot node" "kusama" "kusama node" )
#database=$(menu "Which database do you want to install" 0 75 0 paritydb "Paritydb (newer, quicker)" "rocksdb" "Rocksdb (more stable)" )
database="paritydb"
telemetry=$(menu "Which telemetry to use" 0 75 0 "telemetry.polkadot.io" "default telemetry" "telemetry-backend.w3f.community" "1000 validator telemetry" )
nodedir=$(menu "Where do you want to install" 0 75 0 "/home/polkadot" " best for multi-node install" )
nodename=$(input "How do you want to name your node. This will be used in the systemctl script and in the homedirectory." 0 70 "mynode" )
nodenumber=$(menu "Depending on hardware and network it is possible to install extra nodes, official advise is one node per server. For one node choose 01, for the second 02, etc" 0 75 0 "01" "first node" "02" "Second node" "03" "Third node" )

cat << EOF >> $scriptdir/$nodename-$nodenumber.service
[Unit]
Description=$chain $nodename-$nodenumber
After=network.target
StartLimitIntervalSec=200
StartLimitBurst=2

[Service]
ExecStart=/usr/bin/polkadot --chain $chain --name $nodename-$nodenumber --validator --sync warp --state-pruning 1000 --port 303$nodenumber --rpc-port 99$nodenumber --ws-port 98$nodenumber --prometheus-port 96$nodenumber --prometheus-external --base-path $nodedir/$nodename-$nodenumber --database $database --telemetry-url 'wss://$telemetry/submit 1' 
User=polkadot
Group=polkadot
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF


cat << EOF >> $scriptdir/install.sh
# Install systemctl script
cp $scriptdir/$nodename-$nodenumber.service /etc/systemd/system
systemctl daemon-reload
systemctl enable $nodename-$nodenumber
systemctl start $nodename-$nodenumber
EOF
fi


# Finish script
cat << EOF >> $scriptdir/install.sh
# Endnote
echo "If you installed a node it should be running now and visible from telemetry (tip: start typing to search for your node)"
echo "The script is located in $scriptdir"
echo "For more information see https://stakeworld.io" 
EOF


# Review the script. Starting an editor seems problematic from piped stdin
msg "You can review the script and decide to run or edit. Press q to exit the preview, space for next page."
less $scriptdir/install.sh

if [ -f "$scriptdir/$nodename-$nodenumber.service" ]; then
less "$scriptdir/$nodename-$nodenumber.service"
fi

if (yesno "You want to proceed and runt the script? If you want to review first the script can be found in $scriptdir/install.sh"); then
$scriptdir/install.sh
fi

echo "Optionally you can restore a snapshot, press any key to continue"
read 

# Snapshot
if (yesno "You want to restore a snapshot?"); then

# Start our script
cat << EOF >> $scriptdir/snapshot.sh
#!/bin/bash
# created on $date

EOF

chain=$(menu "Which chain do you want to install" 0 75 0 polkadot "polkadot node" "kusama" "kusama node" )
database=$(menu "Which database do you want to install" 0 75 0 paritydb "Paritydb (newer, quicker)" "rocksdb" "Rocksdb (more stable)" )
snaptargets=`find /home/polkadot /home/polkadot2 /root/.local/share/ -maxdepth 1 -mindepth 1 -type d \( ! -iname ".*" \) -printf "%p -\n" 2> /dev/null`
nodedir=$(menu "Where do you want to install" 0 75 0 $snaptargets )

if [[ $chain = "kusama" ]]
then
    snapchain="ksmcc3"
else
    snapchain="polkadot"
fi

cat << EOF >> $scriptdir/snapshot.sh
# Installing s snapshot
echo "Restoring a snapshot"
systemctl stop $nodename-$nodenumber 2>/dev/null
apt -y install lz4
mkdir -p $nodedir/chains/$snapchain
rm -fr $nodedir/chains/$snapchain/db 2>/dev/null
rm -fr $nodedir/chains/$snapchain/paritydb 2>/dev/null
curl -o - -L http://snapshot.stakeworld.io/$database-$snapchain.lz4 | lz4 -c -d - | tar -x -C $nodedir/chains/$snapchain
chown polkadot:polkadot $nodedir/chains/$snapchain -R
EOF

# Review the script. Starting an editor seems problematic from piped stdin
msg "You can review the script and decide to run or edit. Press q to exit the preview, space for next page."
less $scriptdir/snapshot.sh

if (yesno "You want to proceed and runt the script? If you want to review first the script can be found in $scriptdir/snapshot.sh"); then
$scriptdir/snapshot.sh
fi
fi
