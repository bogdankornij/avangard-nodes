#!/bin/bash
echo "Started"
if [ ! $ASSETN_NODENAME ]; then
	read -p "Назовите ноду (только буквы и цифры): " ASSETN_NODENAME
fi
sleep 1
echo 'export ASSETN_NODENAME='$ASSETN_NODENAME >> $HOME/.profile
echo "Installing..."

#add ufw rules
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/go.sh | bash &>/dev/null
sudo apt install --fix-broken -y &>/dev/null
sudo apt install nano mc wget -y &>/dev/null
source .profile
source .bashrc
sleep 1
echo "Soft installed"
if [ ! -d $HOME/assetMantle/ ]; then
  git clone https://github.com/persistenceOne/assetMantle.git &>/dev/null
	cd $HOME/assetMantle
  git fetch --tags &>/dev/null
	git checkout v0.1.1 &>/dev/null
fi
echo "building..."
cd $HOME/assetMantle
make install &>/dev/null
echo "building end"
echo "configuring node..."
assetNode init $ASSETN_NODENAME --chain-id test-mantle-1 &>/dev/null
wget -O $HOME/.assetNode/config/genesis.json https://raw.githubusercontent.com/persistenceOne/genesisTransactions/master/test-mantle-1/final_genesis.json &>/dev/null
assetNode unsafe-reset-all &>/dev/null
sed -i.bak -e "s/^minimum-gas-prices = \"\"/minimum-gas-prices = \"0.005umantle\"/" $HOME/.assetNode/config/app.toml
peers="9a8a1d3e135531dc452172ce439dc20386064560@75.119.141.248:26656,55e140356200cecaa8f47b24cbbef6147caadda2@192.168.61.24:26656,a9668820073e0d272431e2c30ca9334d3ed22141@192.168.1.77:26656,0c34daf66b3670322d00e0f4593ca07736377ced@142.4.216.69:26656"
external_address=`curl -s ifconfig.me`
sed -i.bak -e "s/^external_address = \"\"/external_address = \"$external_address:26656\"/; s/^persistent_peers *=.*/persistent_peers = \"$peers\"/" $HOME/.assetNode/config/config.toml
wget -O $HOME/.assetNode/config/addrbook.json curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/assetmantle/addrbook.json &>/dev/null
echo "configuring end..."
sudo tee <<EOF >/dev/null /etc/systemd/journald.conf
Storage=persistent
EOF
sudo systemctl restart systemd-journald

sudo tee <<EOF >/dev/null /etc/systemd/system/assetnode.service
[Unit]
Description=assetNode Node
After=network-online.target
[Service]
User=$USER
ExecStart=$(which assetNode) start
Restart=always
RestartSec=10
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable assetnode &>/dev/null
sudo systemctl start assetnode
echo "If you do not see errors - DONE!"