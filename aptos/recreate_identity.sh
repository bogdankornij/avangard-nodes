#!/bin/bash
sudo systemctl stop aptos
sudo rm -rf $HOME/aptos/identity
mkdir -p $HOME/aptos/identity
aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file $HOME/aptos/identity/private-key.txt
aptos-operational-tool extract-peer-from-file --encoding hex --key-file $HOME/aptos/identity/private-key.txt --output-file $HOME/aptos/identity/peer-info.yaml
wget -O $HOME/aptos/seeds.yaml https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/aptos/seeds.yaml
PEER_ID=$(sed -n 2p $HOME/aptos/identity/peer-info.yaml | sed 's/.$//'  | sed 's/://g')
PRIVATE_KEY=$(cat $HOME/aptos/identity/private-key.txt)
WAYPOINT=$(cat $HOME/aptos/waypoint.txt)
cp $HOME/aptos-core/config/src/config/test_data/public_full_node.yaml $HOME/aptos/public_full_node.yaml
sed -i '/network_id: "public"$/a\
      identity:\
        type: "from_config"\
        key: "'$PRIVKEY'"\
        peer_id: "'$PEER'"' $HOME/.aptos/config/public_full_node.yaml

/usr/local/bin/yq ea -i 'select(fileIndex==0).full_node_networks[0].seeds = select(fileIndex==1).seeds | select(fileIndex==0)' $HOME/aptos/public_full_node.yaml $HOME/aptos/seeds.yaml

sed -i 's|127.0.0.1|0.0.0.0|' $HOME/aptos/public_full_node.yaml
sed -i -e "s|genesis_file_location: .*|genesis_file_location: \"$HOME\/aptos\/genesis.blob\"|" $HOME/aptos/public_full_node.yaml
sed -i -e "s|data_dir: .*|data_dir: \"$HOME\/aptos\/data\"|" $HOME/aptos/public_full_node.yaml
sed -i -e "s|0:01234567890ABCDEFFEDCA098765421001234567890ABCDEFFEDCA0987654210|$WAYPOINT|" $HOME/aptos/public_full_node.yaml
sudo systemctl start aptos