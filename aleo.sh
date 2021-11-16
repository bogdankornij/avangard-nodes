#!/bin/bash

#add ufw rules
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash

sudo apt update
sudo apt install curl make clang pkg-config libssl-dev build-essential git mc jq unzip -y
sudo curl https://sh.rustup.rs -sSf | sh -s -- -y
source $HOME/.cargo/env
sleep 1

git clone https://github.com/AleoHQ/snarkOS
cd snarkOS
git checkout v1.3.17
cargo build --release --verbose

cd $HOME
git clone https://github.com/AleoHQ/aleo
cd aleo
git checkout v0.2.0
cargo build --release
sudo cp target/release/aleo /usr/bin/
aleo new >> $HOME/aleo/account.txt
echo 'export ALEO_ADDRESS='$(cat $HOME/aleo/account.txt | awk '/Address/ {print $2}') >> $HOME/.bashrc
source $HOME/.bashrc
sleep 1
echo -e '\n\e[42mYour address - \e[0m' && echo ${ALEO_ADDRESS} && sleep 1

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald

export ALEO_ADDRESS=$(cat $HOME/aleo/account.txt | awk '/Address/ {print $2}')

sudo tee <<EOF >/dev/null /etc/systemd/system/miner.service
[Unit]
Description=Aleo Node
After=network-online.target
[Service]
User=$USER
ExecStart=$HOME/snarkOS/target/release/snarkos --is-miner --miner-address '$ALEO_ADDRESS'
Restart=always
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

cd $HOME
mkdir -p $HOME/.snarkOS

#update snapshot
#block=403000
#wget 167.99.215.126/backup_snarkOS_$block.tar.gz
#tar xvf backup_snarkOS_$block.tar.gz
#mv backup_snarkOS_$block/.snarkOS/* $HOME/.snarkOS/
#rm -rf backup_snarkOS_*

sudo systemctl daemon-reload
sudo systemctl enable miner
sudo systemctl restart miner

echo -e '\n\e[44mSave next output on your PC\e[0m\n' && sleep 1
cat $HOME/aleo/account.txt

echo -e '\n\e[44mRun command to see logs: \e[0m\n'
echo "journalctl -n 100 -f -u miner -o cat | grep -v 'p[io]ng'| grep -v Couldn\'t | grep -v 'Received a' | grep -v 'Sent a' | grep -C1 canon"

tee <<EOF >/dev/null $HOME/monitoring.sh
echo "PEERS:";
curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getpeerinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030/   | jq '.[].peers?';
echo "NODE INFO:";
curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getnodeinfo", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | jq '.result?';
printf "CONNECTION COUNT:\t";
curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getconnectioncount", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | jq '.result?';
printf "BLOCK COUNT:\t\t";
curl -s --data-binary '{"jsonrpc": "2.0", "id":"documentation", "method": "getblockcount", "params": [] }' -H 'content-type: application/json' http://localhost:3030/ | jq '.result?';
echo "OVERALL:";
curl -s --data-binary '{"jsonrpc": "2.0", "id":"1", "method": "getnodestats" }' -H 'content-type:application/json' http://localhost:3030/ | jq '.result?';
echo ""
EOF

chmod +x $HOME/monitoring.sh