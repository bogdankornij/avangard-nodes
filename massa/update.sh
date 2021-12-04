#!/bin/bash

#add ufw rules
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash

sudo systemctl stop massa
rustup toolchain install nightly
rustup default nightly

cd $HOME
mkdir -p $HOME/bk
cp $HOME/massa/massa-node/config/node_privkey.key $HOME/bk/
cp $HOME/massa/massa-client/wallet.dat $HOME/bk/
if [ ! -e $HOME/massa_bk.tar.gz ]; then
	tar cvzf massa_bk.tar.gz bk
fi

rm -rf $HOME/massa
git clone https://github.com/massalabs/massa
cd $HOME/massa
git checkout -- massa-node/config/config.toml
git checkout -- massa-node/config/peers.json
git fetch
git checkout TEST.5.0

cd $HOME/massa/massa-node/
cargo build --release
sed -i "s/ip *=.*/ip = \"127\.0\.0\.1\"/" "$HOME/massa/massa-client/base_config/config.toml"
sed -i "s/^bind_private *=.*/bind_private = \"127\.0\.0\.1\:33034\"/" "$HOME/massa/massa-node/base_config/config.toml"
sed -i "s/^bind_public *=.*/bind_public = \"0\.0\.0\.0\:33035\"/" "$HOME/massa/massa-node/base_config/config.toml"
sed -i 's/.*routable_ip/# \0/' "$HOME/massa/massa-node/base_config/config.toml"
sed -i "/\[network\]/a routable_ip=\"$(curl -s ifconfig.me)\"" "$HOME/massa/massa-node/base_config/config.toml"
cp $HOME/bk/node_privkey.key $HOME/massa/massa-node/config/node_privkey.key

cd $HOME/massa/massa-client/
cargo build --release
cp $HOME/bk/wallet.dat $HOME/massa/massa-client/wallet.dat

sudo systemctl start massa
sleep 10
echo DONE