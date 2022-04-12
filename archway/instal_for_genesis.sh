#!/bin/bash
#add ufw rules
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash

if [ ! $ARCHWAY_NODENAME ]; then
	read -p "Введите имя ноды: " ARCHWAY_NODENAME
fi
echo 'Ваше имя ноды: ' $ARCHWAY_NODENAME
sleep 1
echo 'export ARCHWAY_NODENAME='$ARCHWAY_NODENAME >> $HOME/.profile


sudo apt update
sudo apt install curl -y
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/go.sh | bash


source $HOME/.profile
sleep 1

git clone https://github.com/archway-network/archway
cd archway
git checkout main
make install

cd $HOME
git clone https://github.com/archway-network/testnet-signer
cd testnet-signer
make install
cd $HOME
source $HOME/.profile

chain_id=torii-1
archwayd init $ARCHWAY_NODENAME --chain-id $chain_id
# archwayd keys add $ARCHWAY_NODENAME &>> $HOME/account.txt
#
# archwayd add-genesis-account $ARCHWAY_NODENAME 50000000uflix
#
# archwayd gentx $ARCHWAY_NODENAME 50000000uflix \
#   --pubkey=$(archwayd tendermint show-validator) \
#   --chain-id="$chain_id" \
#   --moniker=$ARCHWAY_NODENAME \
#   --details="$ARCHWAY_NODENAME from DOUBLETOP" \
#   --commission-rate="0.10" \
#   --commission-max-rate="0.20" \
#   --commission-max-change-rate="0.01" \
#   --min-self-delegation="1"

sudo tee /etc/systemd/system/archwayd.service > /dev/null <<EOF
[Unit]
Description=OmniFlixHub Daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which archwayd) start
Restart=always
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable archwayd
#sudo systemctl start archwayd