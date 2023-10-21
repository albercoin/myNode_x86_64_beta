#!/bin/bash

sudo -v

set -x
set -e

# Usage: $0 <ip address | online>
if [ "$#" != "1" ]; then
    echo "Install ONLINE..."
    SERVER_IP=online
else
    echo "Install IP ADDRESS... " $1
    SERVER_IP=$1
fi

# Determine Device
sudo apt install lsb-release

IS_X86=0
IS_32_BIT=0
IS_64_BIT=0
IS_UNKNOWN=1
DEVICE_TYPE="unknown"
LINUX=$(lsb_release -i | awk -F ":" '{printf tolower($2)}' | sed -e 's/^[[:space:]]*//')
if [ $LINUX == "pop" ]; then
    LINUX="ubuntu"
fi   
DEBIAN_VERSION=$(lsb_release -c -s) || DEBIAN_VERSION="unknown"
uname -a | grep x86_64 && IS_X86=1 && IS_64_BIT=1 && IS_UNKNOWN=0 || true
if [ $IS_UNKNOWN = 1 ]; then
    echo "UNKNOWN DEVICE TYPE"
    exit 1
fi


# Source file containing app versions
source /tmp/upgrade/out/rootfs_*/usr/share/mynode/mynode_app_versions.sh

###################################################################################################

###
### Setup myNode (all devices)
### Run with "sudo"
###

set -x
set -e

# Install RTL
echo .
echo "****************************************"
echo "Installing RTL..."
echo "****************************************"
echo .

RTL_UPGRADE_URL=https://github.com/Ride-The-Lightning/RTL/archive/$RTL_VERSION.tar.gz
RTL_UPGRADE_ASC_URL=https://github.com/Ride-The-Lightning/RTL/releases/download/$RTL_VERSION/$RTL_VERSION.tar.gz.asc
CURRENT=""
if [ -f $RTL_VERSION_FILE ]; then
    CURRENT=$(cat $RTL_VERSION_FILE)
fi
if [ "$CURRENT" != "$RTL_VERSION" ]; then
    cd /opt/mynode
    sudo rm -rf RTL
    sudo -u bitcoin wget $RTL_UPGRADE_URL -O RTL.tar.gz
    #sudo -u bitcoin wget $RTL_UPGRADE_ASC_URL -O RTL.tar.gz.asc
    #gpg --verify RTL.tar.gz.asc RTL.tar.gz

    sudo -u bitcoin tar -xvf RTL.tar.gz
    sudo -u bitcoin rm RTL.tar.gz
    sudo -u bitcoin mv RTL-* RTL
    cd RTL
    sudo -u bitcoin NG_CLI_ANALYTICS=false npm install --only=production --legacy-peer-deps
    
    sudo echo $RTL_VERSION > $RTL_VERSION_FILE
    cd
fi

# Install BTC RPC Explorer
echo .
echo "****************************************"
echo "Installing BTC RPC Explorer..."
echo "****************************************"
echo .

BTCRPCEXPLORER_UPGRADE_URL=https://github.com/janoside/btc-rpc-explorer/archive/$BTCRPCEXPLORER_VERSION.tar.gz
CURRENT=""
if [ -f $BTCRPCEXPLORER_VERSION_FILE ]; then
    CURRENT=$(cat $BTCRPCEXPLORER_VERSION_FILE)
fi
if [ "$CURRENT" != "$BTCRPCEXPLORER_VERSION" ]; then
    cd /opt/mynode
    sudo rm -rf btc-rpc-explorer
    sudo -u bitcoin wget $BTCRPCEXPLORER_UPGRADE_URL -O btc-rpc-explorer.tar.gz
    sudo -u bitcoin tar -xvf btc-rpc-explorer.tar.gz
    sudo -u bitcoin rm btc-rpc-explorer.tar.gz
    sudo -u bitcoin mv btc-rpc-* btc-rpc-explorer
    cd btc-rpc-explorer
    sudo -u bitcoin npm install --only=production
    cd

    BTCRPCEXPLORER_VERSION_FILE=$(echo $BTCRPCEXPLORER_VERSION)
fi


# Upgrade Specter Desktop
echo .
echo "****************************************"
echo "Upgrading Specter Desktop..."
echo "****************************************"
echo .

CURRENT=""
if [ -f $SPECTER_VERSION_FILE ]; then
    CURRENT=$(cat $SPECTER_VERSION_FILE)
fi
if [ "$CURRENT" != "$SPECTER_VERSION" ]; then
    cd /opt/mynode
    sudo rm -rf specter
    sudo mkdir -p specter
    sudo chown -R bitcoin:bitcoin specter
    cd specter

    # Make venv
    if [ ! -d env ]; then
        sudo -u bitcoin python3 -m venv env
    fi
    source env/bin/activate
    sudo pip3 install ecdsa===0.13.3
    sudo pip3 install cryptoadvance.specter===$SPECTER_VERSION --upgrade
    deactivate
    cd

    SPECTER_VERSION_FILE=$(echo $SPECTER_VERSION)
fi


# Upgrade Thunderhub
echo .
echo "****************************************"
echo "Upgrading Thunderhub..."
echo "****************************************"
echo .

THUNDERHUB_UPGRADE_URL=https://github.com/apotdevin/thunderhub/archive/$THUNDERHUB_VERSION.tar.gz
CURRENT=""
if [ -f $THUNDERHUB_VERSION_FILE ]; then
    CURRENT=$(cat $THUNDERHUB_VERSION_FILE)
fi
if [ "$CURRENT" != "$THUNDERHUB_VERSION" ]; then
    cd /opt/mynode
    sudo rm -rf thunderhub
    sudo -u bitcoin wget $THUNDERHUB_UPGRADE_URL -O thunderhub.tar.gz
    sudo -u bitcoin tar -xvf thunderhub.tar.gz
    sudo -u bitcoin rm thunderhub.tar.gz
    sudo -u bitcoin mv thunderhub-* thunderhub
    cd thunderhub

    # Patch versions
    sudo sed -i 's/\^5.3.5/5.3.3/g' package.json || true     # Fixes segfault with 5.3.5 on x86

    sudo -u bitcoin npm install --legacy-peer-deps # --only=production # (can't build with only production)
    sudo -u bitcoin npm run build
    sudo -u bitcoin npx next telemetry disable

    # Setup symlink to service files
    sudo rm -f .env.local
    sudo ln -s /mnt/hdd/mynode/thunderhub/.env.local .env.local
    cd

    THUNDERHUB_VERSION_FILE=$(echo $THUNDERHUB_VERSION)
fi


# Install LND Connect
echo .
echo "****************************************"
echo "Installing LND Connect..."
echo "****************************************"
echo .

LNDCONNECTARCH="lndconnect-linux-amd64"
LNDCONNECT_UPGRADE_URL=https://github.com/LN-Zap/lndconnect/releases/download/v0.2.0/$LNDCONNECTARCH-$LNDCONNECT_VERSION.tar.gz
CURRENT=""
if [ -f $LNDCONNECT_VERSION_FILE ]; then
    CURRENT=$(cat $LNDCONNECT_VERSION_FILE)
fi
if [ "$CURRENT" != "$LNDCONNECT_VERSION" ]; then
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download
    sudo wget $LNDCONNECT_UPGRADE_URL -O lndconnect.tar.gz
    sudo tar -xvf lndconnect.tar.gz
    sudo rm lndconnect.tar.gz
    sudo mv lndconnect-* lndconnect
    sudo install -m 0755 -o root -g root -t /usr/local/bin lndconnect/*
    sudo rm -rf /opt/download/*
    cd

    LNDCONNECT_VERSION_FILE=$(echo $LNDCONNECT_VERSION)
fi


# Install ngrok for debugging
echo .
echo "****************************************"
echo "Installing ngrok for debugging..."
echo "****************************************"
echo .

if [ ! -f /usr/bin/ngrok  ]; then
    sudo rm -rf /tmp/ngrok
    sudo mkdir -p /tmp/ngrok
    cd /tmp/ngrok
    NGROK_URL=https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-386.zip
    sudo wget $NGROK_URL
    sudo unzip ngrok-*.zip
    sudo cp ngrok /usr/bin/
    sudo rm -rf /tmp/ngrok
    cd
fi

# Make sure "Remote Access" apps are marked installed
sudo touch /home/bitcoin/.mynode/install_tor
sudo touch /home/bitcoin/.mynode/install_premium_plus
sudo touch /home/bitcoin/.mynode/install_vpn

# Mark docker images for install (on SD so install occurs after drive attach)
sudo touch /home/bitcoin/.mynode/install_mempool
sudo touch /home/bitcoin/.mynode/install_btcpayserver
sudo touch /home/bitcoin/.mynode/install_dojo

# SKIPPING LNBITS - OPTIONAL ALL
# SKIPPING CKBUNKER - OPTIONAL APP
# SKIPPING SPHINX - OPTIONAL APP
# SKIPPING BOS - OPTIONAL APP
# SKIPPING PYBLOCK - OPTIONAL APP
# SKIPPING WARDEN - OPTIONAL APP


# Make sure we are using legacy iptables
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true


#########################################################


# Install files (downloaded and extracted earlier)
sudo rsync -r -K /tmp/upgrade/out/rootfs_*/* /
sudo sync
sleep 1


# Mark dynamic applications as defalt application
# ... (none yet)

# Upgrade Dyanmic Applications (must be done after file installation)
# mynode-manage-apps upgrade # not yet working during setup process


# Random Cleanup
sudo rm -rf /opt/download
sudo mkdir -p /opt/download

# Clean apt-cache
sudo apt-get -y autoclean
sudo apt-get -y autoremove

# Setup myNode Startup Script
sudo systemctl daemon-reload
sudo systemctl enable check_in
sudo systemctl enable premium_plus_connect
sudo systemctl enable background
sudo systemctl enable docker
sudo systemctl enable quicksync
sudo systemctl enable torrent_check
sudo systemctl enable firewall
sudo systemctl enable bandwidth
sudo systemctl enable www
sudo systemctl enable drive_check
sudo systemctl enable bitcoin
sudo systemctl enable seed_bitcoin_peers
sudo systemctl enable lnd
sudo systemctl enable loop
sudo systemctl enable pool
sudo systemctl enable lit
sudo systemctl enable lnd_backup
sudo systemctl enable lnd_admin_files
sudo systemctl enable lndconnect
sudo systemctl enable redis-server
#systemctl enable mongodb
#systemctl enable electrs # DISABLED BY DEFAULT
#systemctl enable lndhub # DISABLED BY DEFAULT
#systemctl enable btcrpcexplorer # DISABLED BY DEFAULT
sudo systemctl enable rtl
sudo systemctl enable tor
sudo systemctl enable i2pd
sudo systemctl enable invalid_block_check
sudo systemctl enable usb_driver_check
sudo systemctl enable docker_images
sudo systemctl enable glances
#systemctl enable netdata # DISABLED BY DEFAULT
sudo systemctl enable webssh2
sudo systemctl enable rotate_logs
sudo systemctl enable corsproxy_btcrpc
sudo systemctl enable usb_extras
sudo systemctl enable ob-watcher

# and now... myNode start
sudo systemctl enable mynode

# Disable services
sudo systemctl disable hitch || true
sudo systemctl disable mongodb || true
sudo systemctl disable dhcpcd || true


# Delete junk
sudo rm -rf /home/admin/download
sudo rm -rf /home/admin/.bash_history
sudo rm -rf /home/bitcoin/.bash_history
sudo rm -rf /root/.bash_history
sudo rm -rf /root/.ssh/known_hosts
sudo rm -rf /etc/resolv.conf
sudo rm -rf /tmp/*
sudo rm -rf ~/setup_device.sh

# Remove existing MOTD login info
sudo rm -rf /etc/motd # Remove simple motd for update-motd.d
sudo rm -rf /etc/update-motd.d/*

# Remove default debian stuff
sudo deluser mynode || true
sudo rm -rf /home/mynode || true

# Add fsck force to startup for x86
if [ $IS_X86 = 1 ]; then
    sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet fsck.mode=force fsck.repair=yes\"/g" /etc/default/grub
    sudo update-grub
fi

# Add generic boot option if UEFI
if [ -f /boot/efi/EFI/debian/grubx64.efi ]; then
    sudo mkdir -p /boot/efi/EFI/BOOT
    sudo cp -f /boot/efi/EFI/debian/grubx64.efi /boot/efi/EFI/BOOT/bootx64.efi
fi

# NOT Expand Root FS
sudo mkdir -p /var/lib/mynode
sudo touch /var/lib/mynode/.expanded_rootfs
sudo sync

# Update host info
sudo hostnamectl set-hostname myNode # sudo echo "myNode" > /etc/hostname

set +x
echo ""
echo ""
echo "##################################"
echo "          SETUP COMPLETE          "
echo "   Reboot your device to begin!   "
echo "##################################"
echo ""
echo ""
echo "You can inspect status myNode with this command:"
echo "sudo journalctl -f -u mynode"
echo ""
echo .
