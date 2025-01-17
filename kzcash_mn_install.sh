#!/bin/bash
#
# Copyright (C) 2019 KZCash Team
#
# mn_install.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# mn_install.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with mn_install.sh. If not, see <http://www.gnu.org/licenses/>
#

# Only Ubuntu 16.04 supported at this moment.

set -o errexit

sudo apt-get update
DEBIAN_FRONTEND=noninteractive sudo apt-get -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade
sudo apt install curl wget unzip git python3 python3-pip python3-virtualenv -y

KZC_DAEMON_USER_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
KZC_DAEMON_RPC_PASS=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 24 ; echo ""`
MN_NAME_PREFIX=`head /dev/urandom | tr -dc A-Za-z0-9 | head -c 6 ; echo ""`
#MN_EXTERNAL_IP=`curl -s -4 ifconfig.co`
#MN_EXTERNAL_IP=`curl ifconfig.co`
MN_EXTERNAL_IP=`curl ifconfig.me`


sudo useradd -U -m kzcash -s /bin/bash
echo "kzcash:${KZC_DAEMON_USER_PASS}" | sudo chpasswd
sudo wget https://github.com/kzcash/mn_install/blob/master/kzcash-0.1.9.1-cli-linux-ubuntu1604.tar.gz
sudo tar -xzvf kzcash-0.1.9.1-cli-linux-ubuntu1604.tar.gz -C /home/kzcash/
#sudo rm /root/kzcash-0.1.9.1-cli-linux-ubuntu1604.tar.gz
sudo mkdir /home/kzcash/.kzcash/
sudo chown -R kzcash:kzcash /home/kzcash/kzcash*
sudo chmod 755 /home/kzcash/kzcash*
echo -e "rpcuser=kzcashrpc\nrpcpassword=${KZC_DAEMON_RPC_PASS}\nlisten=1\nserver=1\nrpcallowip=127.0.0.1\nmaxconnections=256\nprinttodebuglog=0 " | sudo tee /home/kzcash/.kzcash/kzcash.conf
sudo chown -R kzcash:kzcash /home/kzcash/.kzcash/
sudo chmod 500 /home/kzcash/.kzcash/kzcash.conf

sudo tee /etc/systemd/system/kzcash.service <<EOF
[Unit]
Description=KZC, distributed currency daemon
After=network.target

[Service]
User=kzcash
Group=kzcash
WorkingDirectory=/home/kzcash/
ExecStart=/home/kzcash/kzcashd

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable kzcash
sudo systemctl start kzcash
echo "Pause! Waiting (100 sec)... Booting KZC node and creating keypool"
sleep 100

MNGENKEY=`sudo -H -u kzcash /home/kzcash/kzcash-cli masternode genkey`
echo -e "masternode=1\nmasternodeprivkey=${MNGENKEY}\nexternalip=${MN_EXTERNAL_IP}:8277" | sudo tee -a /home/kzcash/.kzcash/kzcash.conf
echo -e '\n\naddnode=161.97.65.233:8277\naddnode=154.26.159.218:8277\naddnode=51.120.7.86:8277\naddnode=167.86.83.90:8277' | tee -a /home/kzcash/.kzcash/kzcash.conf
sudo systemctl restart kzcash

echo "Installing sentinel engine"
sudo git clone https://github.com/kzcash/sentinel.git /home/kzcash/sentinel/
sudo mkdir /home/kzcash/sentinel/database/
sudo chown -R kzcash:kzcash /home/kzcash/sentinel/
cd /home/kzcash/sentinel/
sudo -H -u kzcash virtualenv -p python3 ./venv
sudo -H -u kzcash ./venv/bin/pip install -r requirements.txt
echo "* * * * * kzcash cd /home/kzcash/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" | sudo tee /etc/cron.d/kzcash_sentinel
sudo chmod 644 /etc/cron.d/kzcash_sentinel

echo " "
echo " "
echo "==============================="
echo "Masternode installed!"
echo "==============================="
echo "Copy and keep that information in secret:"
echo "Masternode key: ${MNGENKEY}"
echo "SSH password for user \"kzcash\": ${KZC_DAEMON_USER_PASS}"
echo "Prepared masternode.conf string:"
echo "mn_${MN_NAME_PREFIX} ${MN_EXTERNAL_IP}:8277 ${MNGENKEY} INPUTTX INPUTINDEX"

exit 0
