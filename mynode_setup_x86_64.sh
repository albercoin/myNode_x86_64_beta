#!/bin/bash

###
### Setup myNode (x86_64 devices)
### Run with "sudo"
###

echo "*****************************"
echo "*** myNode x86_64 install ***"
echo "*****************************"

sleep 1
sudo -v

#set -x # set -o xtrace --> trace mode
#set -e # set -o errexit --> error exit mode

# Usage: $0 <ip address | online>
if [ "$#" != "1" ]; then
    echo "Install ONLINE..."
    SERVER_IP=online
else
    echo "Install IP ADDRESS... " $1
    SERVER_IP=$1
fi

# Language of default system
sudo apt-get update
sudo apt-get install -y locales

sudo sed -i '/^# *en_US.UTF-8/s/^#//' /etc/locale.gen
sudo locale-gen en_US.UTF-8
sudo update-locale LANG=en_US.UTF-8

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


# Set kernel settings
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
sudo sysctl -w net.ipv6.conf.lo.disable_ipv6=1


# Set DNS for install (new)
sudo bash -c "echo '' >> /etc/dhcp/dhclient.conf"
sudo bash -c "echo 'append domain-name-servers 1.1.1.1, 8.8.8.8;' >> /etc/dhcp/dhclient.conf"
sudo dhclient -r


# Download rootfs
sudo rm -rf /tmp/rootfs.tar.gz
sudo rm -rf /tmp/upgrade/
sudo mkdir -p /tmp/upgrade

TARBALL=""
if [ $IS_X86 = 1 ]; then
    TARBALL="mynode_rootfs_debian.tar.gz"
fi
if [ "$SERVER_IP" == "online" ]; then
    TARBALL="${TARBALL/"mynode_rootfs_"/"mynode_release_latest_"}"
    sudo wget https://mynodebtc.com/device/upgrade_images/${TARBALL} -O /tmp/rootfs.tar.gz
else
    sudo wget http://${SERVER_IP}:8000/${TARBALL} -O /tmp/rootfs.tar.gz
fi

# Extract rootfs (so we can reference temporary files)
sudo tar -xvf /tmp/rootfs.tar.gz -C /tmp/upgrade/
TMP_INSTALL_PATH="/tmp/upgrade/out/rootfs_*"

# Setup some dependencies
sudo mkdir -p /usr/share/mynode/
sudo cp -f /tmp/upgrade/out/rootfs_*/usr/share/mynode/mynode_device_info.sh /usr/share/mynode/mynode_device_info.sh
sudo cp -f /tmp/upgrade/out/rootfs_*/usr/share/mynode/mynode_config.sh /usr/share/mynode/mynode_config.sh
sudo cp -f /tmp/upgrade/out/rootfs_*/usr/share/mynode/mynode_functions.sh /usr/share/mynode/mynode_functions.sh
sudo cp -f /tmp/upgrade/out/rootfs_*/usr/bin/mynode-get-device-serial /usr/bin/mynode-get-device-serial

# Source file containing app versions
source /tmp/upgrade/out/rootfs_*/usr/share/mynode/mynode_app_versions.sh

# Create any necessary users
sudo useradd -p $(openssl passwd -1 bolt) -m -s /bin/bash admin || true
sudo useradd -m -s /bin/bash bitcoin || true
sudo useradd -m -s /bin/bash joinmarket || true
sudo passwd -l root
sudo adduser admin sudo

# Setup bitcoin user folders
sudo mkdir -p /home/bitcoin/.mynode/
sudo chown bitcoin:bitcoin /home/bitcoin
sudo chown -R bitcoin:bitcoin /home/bitcoin/.mynode/


# Update sources
sudo apt-get -y update --allow-releaseinfo-change

# install SSH
sudo apt-get -y install ssh

# Add sources
sudo apt-get -y install apt-transport-https curl gnupg ca-certificates

# tor project
if [ $IS_64_BIT = 1 ]; then
    sudo grep -qxF "deb https://deb.torproject.org/torproject.org ${DEBIAN_VERSION} main" /etc/apt/sources.list  || sudo bash -c "echo 'deb https://deb.torproject.org/torproject.org ${DEBIAN_VERSION} main' >> /etc/apt/sources.list"
    sudo grep -qxF "deb-src https://deb.torproject.org/torproject.org ${DEBIAN_VERSION} main" /etc/apt/sources.list  || sudo bash -c "echo 'deb-src https://deb.torproject.org/torproject.org ${DEBIAN_VERSION} main' >> /etc/apt/sources.list"
    sudo grep -qxF "deb http://deb.debian.org/debian ${DEBIAN_VERSION}-backports main" /etc/apt/sources.list  || sudo bash -c "echo 'deb http://deb.debian.org/debian ${DEBIAN_VERSION}-backports main' >> /etc/apt/sources.list"
fi

# torrc.d dir
sudo mkdir -p /etc/torrc.d

#################################

# Add I2P Repo
# /bin/bash $TMP_INSTALL_PATH/usr/share/mynode/scripts/add_i2p_repo.sh
# Not working when Pop_OS
echo "Importing I2P signing key"
sudo wget -q -O - https://repo.i2pd.xyz/r4sas.gpg | sudo apt-key --keyring /etc/apt/trusted.gpg.d/i2pd.gpg add -
echo "Adding I2P APT repository"
sudo bash -c "echo 'deb https://repo.i2pd.xyz/$LINUX $DEBIAN_VERSION main' > /etc/apt/sources.list.d/i2pd.list"
sudo bash -c "echo 'deb-src https://repo.i2pd.xyz/$LINUX $DEBIAN_VERSION main' >> /etc/apt/sources.list.d/i2pd.list"

##################################

# Import Keys
# wget https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/builder-keys/keys.txt -O keys.txt
# while read fingerprint keyholder_name; do gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys ${fingerprint}; done < ./keys.txt

sudo curl https://keybase.io/roasbeef/pgp_keys.asc | sudo gpg --import
sudo curl https://keybase.io/bitconner/pgp_keys.asc | sudo gpg --import
sudo curl https://keybase.io/guggero/pgp_keys.asc | sudo gpg --import # Pool
sudo curl https://raw.githubusercontent.com/JoinMarket-Org/joinmarket-clientserver/master/pubkeys/AdamGibson.asc | sudo gpg --import
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 01EA5486DE18A882D4C2684590C8019E36C2E964
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys E777299FC265DD04793070EB944D35F9AC3DB76A # Bitcoin - Michael Ford (fanquake)
sudo curl https://keybase.io/suheb/pgp_keys.asc | sudo gpg --import
sudo curl https://samouraiwallet.com/pgp.txt | sudo gpg --import # two keys from Samourai team
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys DE23E73BFA8A0AD5587D2FCDE80D2F3F311FD87E #loopd
sudo gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 26984CB69EB8C4A26196F7A4D7D916376026F177 # Lightning Terminal
sudo wget -q https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc -O- | sudo apt-key add - # Tor
#sudo wget -qO- https://deb.torproject.org/torproject.org/A3C4F0F979CAA22CDBA8F512EE8CBC9E886DDD89.asc | gpg --dearmor | tee /usr/share/keyrings/tor-archive-keyring.gpg > /dev/null
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 648ACFD622F3D138     # Debian Backports
sudo gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys 0E98404D386FA1D9     # Debian Backports
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 74A941BA219EC810   # Tor
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 66F6C87B98EBCFE2   # I2P (R4SAS)

##################################

# Update OS
# Needed to accept new repos
sudo apt update 

# Freeze any packages we don't want to update
#if [ $IS_X86 = 1 ]; then
#    sudo apt-mark hold grub*
#fi

# Upgrade packages
sudo apt -y upgrade

# Install other tools (run section multiple times to make sure success)
export DEBIAN_FRONTEND=noninteractive
sudo apt-get -y install apt-transport-https lsb-release
sudo apt-get -y install htop git curl bash-completion jq dphys-swapfile lsof libzmq3-dev
sudo apt-get -y install build-essential python3-dev python3-pip python3-grpcio
sudo apt-get -y install transmission-cli fail2ban ufw tclsh redis-server
sudo apt-get -y install clang hitch zlib1g-dev libffi-dev file toilet ncdu
sudo apt-get -y install toilet-fonts avahi-daemon figlet libsecp256k1-dev
sudo apt-get -y install inotify-tools libssl-dev tor tmux screen fonts-dejavu
sudo apt-get -y install pv sysstat network-manager rsync parted unzip pkg-config
sudo apt-get -y install libfreetype6-dev libpng-dev libatlas-base-dev libgmp-dev libltdl-dev
sudo apt-get -y install libffi-dev libssl-dev python3-bottle automake libtool libltdl7
sudo apt-get -y install apt-transport-https ca-certificates
sudo apt-get -y install openjdk-17-jre libevent-dev ncurses-dev
sudo apt-get -y install zlib1g-dev libudev-dev libusb-1.0-0-dev python3-venv gunicorn
sudo apt-get -y install sqlite3 libsqlite3-dev torsocks python3-requests libsystemd-dev
sudo apt-get -y install libjpeg-dev zlib1g-dev psmisc hexyl libbz2-dev liblzma-dev netcat-openbsd
sudo apt-get -y install hdparm iotop nut obfs4proxy libpq-dev socat btrfs-progs i2pd

##################################

# Install packages dependent on Debian release
if [ "$DEBIAN_VERSION" == "bullseye" ] || [ "$DEBIAN_VERSION" == "bookworm" ] || [ "$DEBIAN_VERSION" == "jammy" ]; then
    sudo apt -y install wireguard
else
    echo .
    echo "========================================="
    echo "== UNKNOWN DEBIAN VERSION: $DEBIAN_VERSION"
    echo "== SOME APPS MAY NOT WORK PROPERLY"
    echo "========================================="
    echo .
fi

# Install Openbox GUI if not desktop available
if [ $IS_X86 = 1 ] && [ -z $DESKTOP_SESSION ]; then
    sudo apt -y install xorg chromium openbox lightdm
fi


# Make sure some software is removed
sudo apt -y purge ntp # (conflicts with systemd-timedatectl)
if [ $(lsb_release -i | awk -F ":" '{printf tolower($2)}') != "pop" ]; then
    sudo apt -y purge chrony # (conflicts with systemd-timedatectl)
fi

# Install other things without recommendation
#sudo apt-get -y install --no-install-recommends expect


# Install nginx
sudo mkdir -p /var/log/nginx
$TORIFY sudo apt-get -y install nginx || true
# Install may fail, so we need to edit the default config file and reconfigure
sudo rm -f /etc/nginx/modules-enabled/50-mod-* || true
sudo touch /etc/nginx/sites-available/default
sudo dpkg --configure -a


# Update users
sudo usermod -a -G debian-tor bitcoin

# Make admin a member of bitcoin
sudo adduser admin bitcoin
sudo adduser joinmarket bitcoin
sudo bash -c "grep 'joinmarket' /etc/sudoers || (echo 'joinmarket ALL=(ALL) NOPASSWD:ALL' | EDITOR='tee -a' visudo)"

# Install Go
GO_ARCH="amd64"
GO_UPGRADE_URL=https://go.dev/dl/go$GO_VERSION.linux-$GO_ARCH.tar.gz
CURRENT=""
if [ -f $GO_VERSION_FILE ]; then
    CURRENT=$(cat $GO_VERSION_FILE)
fi
if [ "$CURRENT" != "$GO_VERSION" ]; then
    rm -rf /opt/download
    mkdir -p /opt/download
    cd /opt/download

    wget $GO_UPGRADE_URL -O go.tar.gz
    rm -rf /usr/local/go && tar -C /usr/local -xzf go.tar.gz

    # Mark current version
    echo $GO_VERSION > $GO_VERSION_FILE
fi
echo "export GOBIN=/usr/local/go/bin; PATH=\$PATH:/usr/local/go/bin" > /etc/profile.d/go.sh
grep -qxF '. /etc/profile.d/go.sh' /root/.bashrc || echo '. /etc/profile.d/go.sh' >> /root/.bashrc



# Install Python3 (latest)
CURRENT_PYTHON3_VERSION=$(python3 --version)
if [[ "$CURRENT_PYTHON3_VERSION" != *"Python ${PYTHON_VERSION}"* ]]; then
    sudo mkdir -p /opt/download
    cd /opt/download
    sudo rm -rf Python-*

    sudo wget https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz -O python.tar.xz
    sudo tar xf python.tar.xz

    cd Python-*
    sudo ./configure
    sudo make -j $(nproc)
    sudo make install
    cd ~
else
    echo "Python up to date"
fi


# Install Python3 specific tools
sudo pip3 install --upgrade pip wheel setuptools

sudo pip3 install -r $TMP_INSTALL_PATH/usr/share/mynode/mynode_pip3_requirements.txt --no-cache-dir || \
    sudo pip3 install -r $TMP_INSTALL_PATH/usr/share/mynode/mynode_pip3_requirements.txt --no-cache-dir --use-deprecated=html5lib

# Install node
sudo curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - &&\
sudo apt-get install -y nodejs

# OLD Install node
#if [ ! -f /tmp/installed_node ]; then
#    sudo curl -sL https://deb.nodesource.com/setup_$NODE_JS_VERSION | sudo bash -
#    sudo apt-get install -y nodejs
#    sudo touch /tmp/installed_node
#fi

# install docker
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get -y install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/$LINUX/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:
sudo bash -c "echo \
    'deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$LINUX \
    "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable' | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null"
sudo apt-get update

sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# install latest docker-compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-Linux-x86_64 -o /usr/bin/docker-compose    
sudo chmod +x /usr/bin/docker-compose

# OLD Install docker
#sudo mkdir -p /etc/apt/keyrings
#if [ LINUX == "debian" ]; then
    #sudo curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    #sudo bash -c "echo \
    #  'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    #  $(lsb_release -cs) stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null"
    #sudo apt-get update --allow-releaseinfo-change
    #sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true    
#elif [ LINUX == "ubuntu" ]; then
    #sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
    #sudo bash -c "echo \
    #  'deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    #  $(lsb_release -cs) stable' | tee /etc/apt/sources.list.d/docker.list > /dev/null"
    #sudo apt-get update --allow-releaseinfo-change
    #sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin || true 
#else
    #sudo apt update --allow-releaseinfo-change
    #sudo apt install -y docker docker-compose
#fi

# Use systemd for managing docker
sudo rm -f /etc/init.d/docker
sudo rm -f /etc/systemd/system/multi-user.target.wants/docker.service
sudo systemctl -f enable docker.service

sudo groupadd docker || true
sudo usermod -aG docker admin
sudo usermod -aG docker bitcoin
sudo usermod -aG docker root

##################################

# Install node packages
sudo npm install -g pug-cli browserify uglify-js babel-cli
sudo npm install -g npm@$NODE_NPM_VERSION
sudo npm install -g yarn


#########################################################


# Install Bitcoin
echo .
echo "**********************************"
echo "*** Installing Bitcoin core... ***"
echo "**********************************"
echo .

ARCH="x86_64-linux-gnu"

BTC_UPGRADE_URL=https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/bitcoin-$BTC_VERSION-$ARCH.tar.gz
BTC_UPGRADE_SHA256SUM_URL=https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS
BTC_UPGRADE_SHA256SUM_ASC_URL=https://bitcoincore.org/bin/bitcoin-core-$BTC_VERSION/SHA256SUMS.asc
BTC_CLI_COMPLETION_URL=https://raw.githubusercontent.com/bitcoin/bitcoin/master/contrib/completions/bash/bitcoin-cli.bash
CURRENT=""
if [ -f $BTC_VERSION_FILE ]; then
    CURRENT=$(cat $BTC_VERSION_FILE)
fi
if [ "$CURRENT" != "$BTC_VERSION" ]; then
    # Download and install Bitcoin
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download

    sudo wget $BTC_UPGRADE_URL
    sudo wget $BTC_UPGRADE_SHA256SUM_URL -O SHA256SUMS
    sudo wget $BTC_UPGRADE_SHA256SUM_ASC_URL -O SHA256SUMS.asc

    sudo sha256sum --ignore-missing --check SHA256SUMS

    CHECKSUM=$(sha256sum --ignore-missing --check SHA256SUMS)
    VALORCHECKSUM=$?
    if [ $VALORCHECKSUM -eq 0 ]; then	
    	echo "OK..."
    	echo $(sha256sum --ignore-missing --check SHA256SUMS | awk -F ":" '{printf tolower($2)}')	
    else
    	echo "KO..."
    	echo $(sha256sum --ignore-missing --check SHA256SUMS | awk -F ":" '{printf tolower($2)}')
    	exit $VALORCHECKSUM
    fi
    
    curl -s "https://api.github.com/repositories/355107265/contents/builder-keys" | grep download_url | grep -oE "https://[a-zA-Z0-9./-]+" | while read url; do curl -s "$url" | gpg --import; done
    gpg --verify SHA256SUMS.asc
    

    # Install Bitcoin
    sudo tar -xvf bitcoin-$BTC_VERSION-$ARCH.tar.gz
    sudo mv bitcoin-$BTC_VERSION bitcoin
    sudo install -m 0755 -o root -g root -t /usr/local/bin bitcoin/bin/*
    
    if [ ! -L /home/bitcoin/.bitcoin ]; then
        sudo rm -f /home/bitcoin/.bitcoin
        sudo -u bitcoin ln -s /mnt/hdd/mynode/bitcoin /home/bitcoin/.bitcoin
    fi
    
    sudo mkdir -p /home/admin/.bitcoin    
    # Mark current version
    sudo -u bitcoin echo $BTC_VERSION | sudo -u bitcoin tee $BTC_VERSION_FILE

    # Install bash-completion for bitcoin-cli
    sudo wget $BTC_CLI_COMPLETION_URL -O bitcoin-cli.bash
    sudo cp bitcoin-cli.bash /etc/bash_completion.d/bitcoin-cli
    
    sudo rm -rf /opt/download/*
    cd
fi



# Install Lightning
echo .
echo "*******************************"
echo "*** Installing Lightning... ***"
echo "*******************************"
echo .

LND_ARCH="lnd-linux-amd64"
LND_UPGRADE_URL=https://github.com/lightningnetwork/lnd/releases/download/$LND_VERSION/$LND_ARCH-$LND_VERSION.tar.gz
LNCLI_COMPLETION_URL=https://raw.githubusercontent.com/lightningnetwork/lnd/$LND_VERSION/contrib/lncli.bash-completion
CURRENT=""
if [ -f $LND_VERSION_FILE ]; then
    CURRENT=$(cat $LND_VERSION_FILE)
fi
if [ "$CURRENT" != "$LND_VERSION" ]; then
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download

    sudo wget $LND_UPGRADE_URL
    sudo wget $LND_UPGRADE_MANIFEST_URL -O manifest.txt
    sudo wget $LND_UPGRADE_MANIFEST_ROASBEEF_SIG_URL -O manifest_roasbeef.txt.sig || true
    sudo wget $LND_UPGRADE_MANIFEST_GUGGERO_SIG_URL -O manifest_guggero.txt.sig || true

    sudo gpg --verify manifest_roasbeef.txt.sig manifest.txt || \
    sudo gpg --verify manifest_guggero.txt.sig manifest.txt

    sudo tar -xzf lnd-*.tar.gz
    sudo mv $LND_ARCH-$LND_VERSION lnd
    sudo install -m 0755 -o root -g root -t /usr/local/bin lnd/*
    #sudo ln -s /bin/ip /usr/bin/ip || true
    
    if [ ! -L /home/bitcoin/.lnd ]; then
        sudo rm -f /home/bitcoin/.lnd
        sudo -u bitcoin ln -s /mnt/hdd/mynode/lnd /home/bitcoin/.lnd
    fi

    # Mark current version
    sudo -u bitcoin echo $LND_VERSION | sudo -u bitcoin tee $LND_VERSION_FILE

    # Download bash-completion file for lncli
    sudo wget $LNCLI_COMPLETION_URL
    sudo cp lncli.bash-completion /etc/bash_completion.d/lncli
    
    sudo rm -rf /opt/download/*
    cd
fi



# Install Loop
echo .
echo "**************************"
echo "*** Installing loop... ***"
echo "**************************"
echo .

LOOP_ARCH="loop-linux-amd64"
LOOP_UPGRADE_URL=https://github.com/lightninglabs/loop/releases/download/$LOOP_VERSION/$LOOP_ARCH-$LOOP_VERSION.tar.gz
CURRENT=""
if [ -f $LOOP_VERSION_FILE ]; then
    CURRENT=$(cat $LOOP_VERSION_FILE)
fi
if [ "$CURRENT" != "$LOOP_VERSION" ]; then
    # Download and install Loop
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download

    sudo wget $LOOP_UPGRADE_URL
    sudo wget $LOOP_UPGRADE_MANIFEST_URL -O manifest.txt
    sudo wget $LOOP_UPGRADE_MANIFEST_SIG_URL -O manifest.txt.sig

    CHECKSUM=$(sha256sum --ignore-missing --check manifest.txt)
    VALORCHECKSUM=$?
    if [ $VALORCHECKSUM -eq 0 ]; then	
    	echo "OK..."
    	echo $(sha256sum --ignore-missing --check manifest.txt | awk -F ":" '{printf tolower($2)}')	
        # Install Loop
        sudo tar -xzf loop-*.tar.gz
        sudo mv $LOOP_ARCH-$LOOP_VERSION loop
        sudo install -m 0755 -o root -g root -t /usr/local/bin loop/*

        # Mark current version
        sudo -u bitcoin echo $LOOP_VERSION | sudo -u bitcoin tee $LOOP_VERSION_FILE
    else
    	echo "KO..."
    	echo $(sha256sum --ignore-missing --check manifest.txt | awk -F ":" '{printf tolower($2)}')
        echo "ERROR UPGRADING LND - GPG FAILED"
    	exit $VALORCHECKSUM
    fi
    
    sudo rm -rf /opt/download/*
    cd
fi



POOL_ARCH="pool-linux-amd64"
POOL_UPGRADE_URL=https://github.com/lightninglabs/pool/releases/download/$POOL_VERSION/$POOL_ARCH-$POOL_VERSION.tar.gz
CURRENT=""
if [ -f $POOL_VERSION_FILE ]; then
    CURRENT=$(cat $POOL_VERSION_FILE)
fi
if [ "$CURRENT" != "$POOL_VERSION" ]; then
    # Download and install pool
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download

    sudo wget $POOL_UPGRADE_URL
    sudo wget $POOL_UPGRADE_MANIFEST_URL -O manifest.txt
    sudo wget $POOL_UPGRADE_MANIFEST_SIG_URL -O manifest.txt.sig

    sudo gpg --verify manifest.txt.sig manifest.txt
    VAL=$?
    if [ $VAL == 0 ]; then
        # Install Pool
        sudo tar -xzf pool-*.tar.gz
        sudo mv $POOL_ARCH-$POOL_VERSION pool
        sudo install -m 0755 -o root -g root -t /usr/local/bin pool/*

        # Mark current version
        sudo -u bitcoin echo $POOL_VERSION | sudo -u bitcoin tee $POOL_VERSION_FILE
    else
        echo "ERROR UPGRADING POOL - GPG FAILED"
    fi
    sudo rm -rf /opt/download/*
    cd
fi



# Install Lightning Terminal
echo .
echo "****************************************"
echo "*** Installing Lightning Terminal... ***"
echo "****************************************"
echo .

LIT_ARCH="lightning-terminal-linux-amd64"
LIT_UPGRADE_URL=https://github.com/lightninglabs/lightning-terminal/releases/download/$LIT_VERSION/$LIT_ARCH-$LIT_VERSION.tar.gz
CURRENT=""
if [ -f $LIT_VERSION_FILE ]; then
    CURRENT=$(cat $LIT_VERSION_FILE)
fi
if [ "$CURRENT" != "$LIT_VERSION" ]; then
    # Download and install lit
    sudo rm -rf /opt/download
    sudo mkdir -p /opt/download
    cd /opt/download

    sudo wget $LIT_UPGRADE_URL
    sudo wget $LIT_UPGRADE_MANIFEST_URL -O manifest.txt
    sudo wget $LIT_UPGRADE_MANIFEST_SIG_URL  -O manifest.txt.sig

    sudo gpg --verify manifest.txt.sig manifest.txt
    VAL=$?
    if [ $VAL == 0 ]; then
        # Install lit
        sudo tar -xzf lightning-terminal-*.tar.gz
        sudo mv $LIT_ARCH-$LIT_VERSION lightning-terminal
        sudo sudo install -m 0755 -o root -g root -t /usr/local/bin lightning-terminal/lit*

        # Mark current version
        sudo -u bitcoin echo $LIT_VERSION | sudo -u bitcoin tee $LIT_VERSION_FILE
    else
        echo "ERROR UPGRADING LIT - GPG FAILED"
    fi
    sudo rm -rf /opt/download/*
    cd
fi

# Upgrade Lightning Chantools
echo "Upgrading chantools..."

CHANTOOLS_ARCH="chantools-linux-amd64"
CHANTOOLS_UPGRADE_URL=https://github.com/lightninglabs/chantools/releases/download/$CHANTOOLS_VERSION/$CHANTOOLS_ARCH-$CHANTOOLS_VERSION.tar.gz
CURRENT=""
if [ -f $CHANTOOLS_VERSION_FILE ]; then
    CURRENT=$(cat $CHANTOOLS_VERSION_FILE)
fi
if [ "$CURRENT" != "$CHANTOOLS_VERSION" ]; then
    # Download and install lit
    rm -rf /opt/download
    mkdir -p /opt/download
    cd /opt/download

    wget $CHANTOOLS_UPGRADE_URL
    wget $CHANTOOLS_UPGRADE_MANIFEST_URL -O manifest.txt
    wget $CHANTOOLS_UPGRADE_MANIFEST_SIG_URL  -O manifest.txt.sig

    gpg --verify manifest.txt.sig manifest.txt
    if [ $? == 0 ]; then
        # Install lit
        tar -xzf chantools-*.tar.gz
        mv $CHANTOOLS_ARCH-$CHANTOOLS_VERSION chantools
        install -m 0755 -o root -g root -t /usr/local/bin chantools/chantools

        # Mark current version
        sudo -u bitcoin echo $CHANTOOLS_VERSION | sudo -u bitcoin tee $CHANTOOLS_VERSION_FILE
    else
        echo "ERROR UPGRADING CHANTOOLS - GPG FAILED"
    fi
fi
cd ~


# Setup "install" location for some apps
sudo mkdir -p /opt/mynode
sudo chown -R bitcoin:bitcoin /opt/mynode



# Install cors proxy (my fork)
echo .
echo "****************************************"
echo "Installing cors proxy by tehelsper..."
echo "****************************************"
echo .

CORSPROXY_UPGRADE_URL=https://github.com/tehelsper/CORS-Proxy/archive/$CORSPROXY_VERSION.tar.gz
CURRENT=""
if [ -f $CORSPROXY_VERSION_FILE ]; then
    CURRENT=$(cat $CORSPROXY_VERSION_FILE)
fi
if [ "$CURRENT" != "$CORSPROXY_VERSION" ]; then
    cd /opt/mynode
    sudo rm -rf corsproxy

    sudo rm -f corsproxy.tar.gz
    sudo wget $CORSPROXY_UPGRADE_URL -O corsproxy.tar.gz
    sudo tar -xzf corsproxy.tar.gz
    sudo rm -f corsproxy.tar.gz
    sudo mv CORS-* corsproxy

    cd corsproxy
    sudo npm install
    cd
    # Mark current version
   sudo -u bitcoin echo $CORSPROXY_VERSION | sudo -u bitcoin tee $CORSPROXY_VERSION_FILE
fi


# Install Electrs (just mark version, now included in overlay)
echo .
echo "Installing Server Electrum --> Electrs..."
echo .

# Mark current version
sudo -u bitcoin echo $ELECTRS_VERSION | sudo -u bitcoin tee $ELECTRS_VERSION_FILE


# Install recent version of secp256k1
echo .
echo "****************************************"
echo "Installing secp256k1..."
echo "****************************************"
echo .

SECP256K1_UPGRADE_URL=https://github.com/bitcoin-core/secp256k1/archive/$SECP256K1_VERSION.tar.gz
CURRENT=""
if [ -f $SECP256K1_VERSION_FILE ]; then
    CURRENT=$(cat $SECP256K1_VERSION_FILE)
fi
if [ "$CURRENT" != "$SECP256K1_VERSION" ]; then
    sudo rm -rf /tmp/secp256k1
    cd /tmp/
    sudo git clone https://github.com/bitcoin-core/secp256k1.git
    cd secp256k1

    sudo ./autogen.sh
    sudo ./configure --enable-module-recovery --disable-jni --enable-experimental --enable-module-ecdh --enable-benchmark=no
    sudo make -j $(nproc)
    sudo make install
    sudo cp -f include/* /usr/include/
    sudo rm -rf /tmp/secp256k1
    cd

    # Mark current version
    sudo -u bitcoin echo $SECP256K1_VERSION | sudo -u bitcoin tee $SECP256K1_VERSION_FILE
fi

# Install JoinInBox
echo .
echo "****************************************"
echo "Installing JoinInBox..."
echo "****************************************"
echo .

JOININBOX_UPGRADE_URL=https://github.com/openoms/joininbox/archive/$JOININBOX_VERSION.tar.gz
CURRENT=""
if [ -f $JOININBOX_VERSION_FILE ]; then
    CURRENT=$(cat $JOININBOX_VERSION_FILE)
fi
if [ "$CURRENT" != "$JOININBOX_VERSION" ]; then
    # Delete all non-hidden files
    sudo rm -rf /home/joinmarket/*    

    # Download and build JoinInBox
    sudo -u joinmarket wget $JOININBOX_UPGRADE_URL -O /home/joinmarket/joininbox.tar.gz
    sudo -u joinmarket tar -xvf /home/joinmarket/joininbox.tar.gz -C /home/joinmarket/
    sudo -u joinmarket rm /home/joinmarket/joininbox.tar.gz
    sudo -u joinmarket bash -c "mv /home/joinmarket/joininbox-* /home/joinmarket/joininbox"

    sudo -u joinmarket chmod -R +x /home/joinmarket/joininbox/
    sudo -u joinmarket bash -c "cp -rf /home/joinmarket/joininbox/scripts/* /home/joinmarket/"

    # Install
    sudo -u joinmarket bash -c "cd /home/joinmarket/; ${JM_ENV_VARS} ./install.joinmarket.sh --install install" || true
    sudo -u joinmarket bash -c "cd /home/joinmarket/; ${JM_ENV_VARS} ./install.joinmarket-api.sh on" || true

    # Enable obwatcher at the end of setup_device.sh

    cd

    # Mark current version
    sudo -u bitcoin echo $JOININBOX_VERSION | sudo -u bitcoin tee $JOININBOX_VERSION_FILE
fi

# Install Whirlpool
echo .
echo "****************************************"
echo "Installing Whirlpool..."
echo "****************************************"
echo .

WHIRLPOOL_UPGRADE_URL=https://code.samourai.io/whirlpool/whirlpool-client-cli/uploads/$WHIRLPOOL_UPLOAD_FILE_ID/whirlpool-client-cli-$WHIRLPOOL_VERSION-run.jar
CURRENT=""
if [ -f $WHIRLPOOL_VERSION_FILE ]; then
    CURRENT=$(cat $WHIRLPOOL_VERSION_FILE)
fi
if [ "$CURRENT" != "$WHIRLPOOL_VERSION" ]; then
    sudo -u bitcoin mkdir -p /opt/mynode/whirlpool
    cd /opt/mynode/whirlpool
    sudo rm -rf *.jar
    sudo -u bitcoin wget -O whirlpool.jar $WHIRLPOOL_UPGRADE_URL

    sudo -u bitcoin cp -f $TMP_INSTALL_PATH/usr/share/whirlpool/whirlpool.asc /opt/mynode/whirlpool/whirlpool.asc
    sudo gpg --verify whirlpool.asc
    cd

    # Mark current version
    sudo -u bitcoin echo $WHIRLPOOL_VERSION | sudo -u bitcoin tee $WHIRLPOOL_VERSION_FILE
fi

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
    
    # Mark current version
    sudo -u bitcoin echo $RTL_VERSION | sudo -u bitcoin tee $RTL_VERSION_FILE
    
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

    # Mark current version
    sudo -u bitcoin echo $BTCRPCEXPLORER_VERSION | sudo -u bitcoin tee $BTCRPCEXPLORER_VERSION_FILE
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

    # Mark current version
    sudo -u bitcoin echo $SPECTER_VERSION | sudo -u bitcoin tee $SPECTER_VERSION_FILE
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

    # Mark current version
    sudo -u bitcoin echo $THUNDERHUB_VERSION | sudo -u bitcoin tee $THUNDERHUB_VERSION_FILE
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

    # Mark current version
    sudo -u bitcoin echo $LNDCONNECT_VERSION | sudo -u bitcoin tee $LNDCONNECT_VERSION_FILE
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
#sudo update-alternatives --set iptables /usr/sbin/iptables-legacy || true
#sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true


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
sudo apt -y autoremove
sudo apt -y autoclean

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
#sudo rm -rf /etc/resolv.conf
sudo rm -rf /tmp/*
sudo rm -rf ~/setup_device.sh
sudo rm -rf /etc/motd # Remove simple motd for update-motd.d


# Add fsck force to startup for x86
if [ $IS_X86 = 1 ]; then
    sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"quiet fsck.mode=force fsck.repair=yes\"/g" /etc/default/grub
    sudo update-grub
fi

# Add generic boot option if UEFI
#if [ -f /boot/efi/EFI/debian/grubx64.efi ]; then
#    sudo mkdir -p /boot/efi/EFI/BOOT
#    sudo cp -f /boot/efi/EFI/debian/grubx64.efi /boot/efi/EFI/BOOT/bootx64.efi
#fi

# NOT Expand Root FS
sudo mkdir -p /var/lib/mynode
sudo touch /var/lib/mynode/.expanded_rootfs
sudo sync

# Update host info
sudo sed -i "s/$HOSTNAME/myNode/" /etc/hosts
sudo hostnamectl set-hostname myNode # sudo echo "myNode" > /etc/hostname

# Remove default debian stuff
#sudo deluser $USER || true
#sudo rm -rf /home/$USER || true

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

