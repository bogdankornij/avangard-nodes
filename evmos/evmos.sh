#!/bin/bash
if [ ! $EVMOS_NODENAME ]; then
	read -p "Введите ваше имя ноды(придумайте, без спецсимволов - только буквы и цифры): " EVMOS_NODENAME
fi
sleep 1
echo 'export EVMOS_NODENAME='$EVMOS_NODENAME >> $HOME/.profile
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash &>/dev/null
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/go.sh | bash &>/dev/null
sudo apt install --fix-broken -y &>/dev/null
sudo apt install nano mc wget -y &>/dev/null
source .profile
source .bashrc
sleep 1

git clone https://github.com/cosmos/cosmos-sdk
cd cosmos-sdk
git checkout v0.44.3
make cosmovisor
cp cosmovisor/cosmovisor $GOPATH/bin/cosmovisor
cd $HOME

mkdir -p ~/.evmosd
mkdir -p ~/.evmosd/cosmovisor
mkdir -p ~/.evmosd/cosmovisor/genesis
mkdir -p ~/.evmosd/cosmovisor/genesis/bin
mkdir -p ~/.evmosd/cosmovisor/upgrades

echo "# Setup Cosmovisor" >> ~/.profile
echo "export DAEMON_NAME=evmosd" >> ~/.profile
echo "export DAEMON_HOME=$HOME/.evmosd" >> ~/.profile
echo 'export PATH="$DAEMON_HOME/cosmovisor/current/bin:$PATH"' >> ~/.profile
source ~/.profile

if [ ! -d $HOME/evmos/ ]; then
  git clone https://github.com/tharsis/evmos.git &>/dev/null
	cd $HOME/evmos
	git checkout v0.3.0 &>/dev/null
fi
cd $HOME/evmos
make install &>/dev/null
evmosd config chain-id evmos_9000-2 &>/dev/null
evmosd config keyring-backend file &>/dev/null
evmosd init "$EVMOS_NODENAME" --chain-id evmos_9000-2 &>/dev/null
curl -s https://raw.githubusercontent.com/tharsis/testnets/main/olympus_mons/genesis.json > ~/.evmosd/config/genesis.json
curl -s https://raw.githubusercontent.com/tharsis/testnets/main/olympus_mons/peers.txt > peers.txt
evmosd unsafe-reset-all
PEERS=`awk '{print $1}' peers.txt | paste -s -d, -`
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" ~/.evmosd/config/config.toml
grep -qxF 'evm-timeout = "5s"' $HOME/.evmosd/config/app.toml || sed -i "/\[json-rpc\]/a evm-timeout = \"5s\"" $HOME/.evmosd/config/app.toml
grep -qxF "txfee-cap = 1" $HOME/.evmosd/config/app.toml || sed -i "/\[json-rpc\]/a txfee-cap = 1" $HOME/.evmosd/config/app.toml
grep -qxF "filter-cap = 200" $HOME/.evmosd/config/app.toml || sed -i "/\[json-rpc\]/a filter-cap = 200" $HOME/.evmosd/config/app.toml
grep -qxF "feehistory-cap = 100" $HOME/.evmosd/config/app.toml || sed -i "/\[json-rpc\]/a feehistory-cap = 100" $HOME/.evmosd/config/app.toml

sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald

sudo tee /etc/systemd/system/evmos.service > /dev/null <<EOF
[Unit]
Description=Evmos Daemon
After=network-online.target

[Service]
User=$USER
ExecStart=$(which cosmovisor) start
Restart=always
RestartSec=3
LimitNOFILE=infinity

Environment="DAEMON_HOME=$HOME/.evmosd"
Environment="DAEMON_NAME=evmosd"
Environment="DAEMON_ALLOW_DOWNLOAD_BINARIES=false"
Environment="DAEMON_RESTART_AFTER_UPGRADE=true"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable evmos &>/dev/null
sudo systemctl start evmos
echo "ГОТОВО!"