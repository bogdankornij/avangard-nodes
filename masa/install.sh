#!/bin/bash
if [ ! $MASA_NODENAME ]; then
	read -p "Введите ваше имя ноды (придумайте, без спецсимволов - только буквы и цифры): " MASA_NODENAME
fi
sleep 1
echo 'export MASA_NODENAME='$MASA_NODENAME >> $HOME/.profile
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash &>/dev/null
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/go.sh | bash &>/dev/null
sudo apt install nano mc wget -y &>/dev/null
source .profile
sleep 1
cd $HOME
sudo apt install apt-transport-https -y &>/dev/null

if [ ! -d $HOME/masa-node-v1.0/ ]; then
  git clone https://github.com/masa-finance/masa-node-v1.0 &>/dev/null
fi
cd $HOME/masa-node-v1.0/src
git checkout v1.02
make all &>/dev/null
go get github.com/ethereum/go-ethereum/accounts/keystore &>/dev/null
cd $HOME/masa-node-v1.0/src/build/bin
cp * /usr/local/bin
echo "Ставим geth quorum"
cd $HOME
wget https://artifacts.consensys.net/public/go-quorum/raw/versions/v21.10.0/geth_v21.10.0_linux_amd64.tar.gz &>/dev/null
tar -xvf geth_v21.10.0_linux_amd64.tar.gz &>/dev/null
rm -v geth_v21.10.0_linux_amd64.tar.gz &>/dev/null
chmod +x $HOME/geth
sudo mv -f $HOME/geth /usr/bin/
echo "Инициализируем ноду"
cd $HOME/masa-node-v1.0
geth --datadir data init ./network/testnet/genesis.json
PRIVATE_CONFIG=ignore
echo 'export PRIVATE_CONFIG='${PRIVATE_CONFIG} >> $HOME/.profile
source $HOME/.profile
sudo tee /etc/systemd/system/masad.service > /dev/null <<EOF
[Unit]
Description=MASA
After=network.target
[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/geth --identity ${MASA_NODENAME} --datadir $HOME/masa-node-v1.0/data --bootnodes enode://ac6b1096ca56b9f6d004b779ae3728bf83f8e22453404cc3cef16a3d9b96608bc67c4b30db88e0a5a6c6390213f7acbe1153ff6d23ce57380104288ae19373ef@172.16.239.11:21000  --emitcheckpoints --istanbul.blockperiod 1 --mine --minerthreads 1 --syncmode full --verbosity 5 --networkid 190250 --rpc --rpccorsdomain "*" --rpcvhosts "*" --rpcaddr 127.0.0.1 --rpcport 8545 --rpcapi admin,db,eth,debug,miner,net,shh,txpool,personal,web3,quorum,istanbul --port 30300
Restart=on-failure
RestartSec=10
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable masad
sudo systemctl restart masad

echo 'ГОТОВО!';
echo ' ';
echo '|\  ||  /|';
echo '--  ||  --';
echo '|/__/\__\|';
echo '    \/';
