#!/bin/bash
#thanks zvalid.com for https://api.zvalid.com/aptos.sh

echo -e "\e[1m\e[32m1. Updating list of dependencies... \e[0m" && sleep 1
curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/ufw.sh | bash &>/dev/null
sudo apt-get install jq mc wget git -y &>/dev/null
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 &>/dev/null
sudo chmod a+x /usr/local/bin/yq
echo -e "\e[1m\e[32m2. Checking if Docker is installed... \e[0m" && sleep 1

if ! command -v docker &> /dev/null
then

    echo -e "\e[1m\e[32m2.1 Installing Docker... \e[0m" && sleep 1
    sudo apt-get install ca-certificates curl gnupg lsb-release wget -y
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io -y
fi

echo -e "\e[1m\e[32m3. Checking if Docker Compose is installed ... \e[0m" && sleep 1

docker compose version &> /dev/null
if [ $? -ne 0 ]
then

    echo -e "\e[1m\e[32m3.1 Installing Docker Compose v2.3.3 ... \e[0m" && sleep 1
    mkdir -p ~/.docker/cli-plugins/
    curl -SL https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
    chmod +x ~/.docker/cli-plugins/docker-compose
    sudo chown $USER /var/run/docker.sock
fi

cd $HOME


echo -e "\e[1m\e[32m4. Downloading Aptos FullNode config files ... \e[0m" && sleep 1

sudo mkdir -p $HOME/aptos/identity
cd $HOME/aptos
docker compose -f $HOME/aptos/docker-compose.yaml stop
rm *
wget -P $HOME/aptos https://raw.githubusercontent.com/aptos-labs/aptos-core/main/docker/compose/public_full_node/docker-compose.yaml
wget -P $HOME/aptos https://raw.githubusercontent.com/aptos-labs/aptos-core/main/docker/compose/public_full_node/public_full_node.yaml
wget -P $HOME/aptos https://devnet.aptoslabs.com/genesis.blob
wget -P $HOME/aptos https://devnet.aptoslabs.com/waypoint.txt
wget -P $HOME/aptos https://api.zvalid.com/aptos/seeds.yaml

# echo "-----------------------------------------------------------------------------"
# echo -e "\e[1m\e[32m4.1 Pull docker images \e[0m"
# cd $HOME
# git clone https://github.com/aptos-labs/aptos-core.git
# cd $HOME/aptos-core
# git checkout origin/devnet &>/dev/null
# cd $HOME/aptos-core/docker/tools
# ./build.sh
# cd $HOME/aptos-core/docker/validator
# ./build.sh
#
# docker rmi -f aptoslab/tools:devnet aptoslab/validator:devnet
# docker tag aptos/validator:latest aptoslab/validator:devnet
# docker tag aptos/tools:latest aptoslab/tools:devnet
#
# cd $HOME/aptos

#docker pull aptoslab/tools@sha256:3147fd80ba3985768be4d83a34d48b972e357acb47fc048155acf0d698df3e91
#docker pull aptoslab/validator@sha256:acc274d17879f9562cf05f3c7655450f9df9416d4d2aff03d17584b69e0c0367

# Checking if aptos node identity exists
create_identity(){
    echo -e "\e[1m\e[32m4.1 Creating a unique node identity \e[0m"
    docker run --rm --name aptos_tools -d -i aptoslab/tools:devnet
    docker exec -it aptos_tools aptos-operational-tool generate-key --encoding hex --key-type x25519 --key-file $HOME/private-key.txt
    docker exec -it aptos_tools cat $HOME/private-key.txt > $HOME/aptos/identity/private-key.txt
    docker exec -it aptos_tools aptos-operational-tool extract-peer-from-file --encoding hex --key-file $HOME/private-key.txt --output-file $HOME/peer-info.yaml > $HOME/aptos/identity/id.json
    docker exec -it aptos_tools cat $HOME/peer-info.yaml > $HOME/aptos/identity/peer-info.yaml
    PEER_ID=$(cat $HOME/aptos/identity/id.json | jq -r '.Result | keys[]')
    PRIVATE_KEY=$(cat $HOME/aptos/identity/private-key.txt)

    docker stop aptos_tools
    if [ ! -z "$PRIVATE_KEY" ]
    then
        echo -e "\e[1m\e[92m Identity was successfully created \e[0m"
        echo -e "\e[1m\e[92m Peer Id: \e[0m" $PEER_ID
        echo -e "\e[1m\e[92m Private Key:  \e[0m" $PRIVATE_KEY
    else
        rm $HOME/aptos/identity/id.json
        rm $HOME/aptos/identity/private-key.txt
        echo -e "\e[1m\e[91m Wasn't able to create the Identity. FullNode will be started without the identity, identity can be added manually \e[0m"
    fi
}

if [[ -f $HOME/aptos/identity/id.json && -f $HOME/aptos/identity/private-key.txt ]]
then

    PEER_ID=$(cat $HOME/aptos/identity/id.json | jq -r '.Result | keys[]')
    PRIVATE_KEY=$(cat $HOME/aptos/identity/private-key.txt)

    if [ ! -z "$PRIVATE_KEY" ]
    then
        echo -e "\e[1m\e[92m Peer Id: \e[0m" $PEER_ID
        echo -e "\e[1m\e[92m Private Key:  \e[0m" $PRIVATE_KEY
    else
        rm $HOME/aptos/identity/id.json
        rm $HOME/aptos/identity/private-key.txt
        create_identity
    fi
else

    create_identity
fi

if [ ! -z "$PRIVATE_KEY" ]
then
    # Setting node identity
    /usr/local/bin/yq e -i '.full_node_networks[] +=  { "identity": {"type": "from_config", "key": "'$PRIVATE_KEY'", "peer_id": "'$PEER_ID'"} }' $HOME/aptos/public_full_node.yaml

    # Setting peer list
    /usr/local/bin/yq ea -i 'select(fileIndex==0).full_node_networks[0].seeds = select(fileIndex==1).seeds | select(fileIndex==0)' $HOME/aptos/public_full_node.yaml $HOME/aptos/seeds.yaml
    rm $HOME/aptos/seeds.yaml
fi

echo -e "\e[1m\e[32m5. Starting Aptos FullNode ... \e[0m" && sleep 5

docker compose up -d


echo -e "\e[1m\e[32mAptos FullNode Started \e[0m"


if [ ! -z "$PRIVATE_KEY" ]
then
    echo -e "\e[1m\e[32mPrivate key file location. It is recommended to back it up: \e[0m"
    echo -e "\e[1m\e[39m"    $HOME/aptos/identity/private-key.txt" \n \e[0m"

    echo -e "\e[1m\e[32mPeer info file location. It is recommended to back it up: \e[0m"
    echo -e "\e[1m\e[39m"    $HOME/aptos/identity/peer-info.yaml" \n \e[0m"
fi

echo -e "\e[1m\e[32mTo check sync status: \e[0m"
echo -e "\e[1m\e[39m    curl 127.0.0.1:9101/metrics 2> /dev/null | grep aptos_state_sync_version | grep type \n \e[0m"

echo -e "\e[1m\e[32mTo view logs: \e[0m"
echo -e "\e[1m\e[39m    docker logs -f aptos-fullnode-1 --tail 5000 \n \e[0m"

echo -e "\e[1m\e[32mTo stop: \e[0m"
echo -e "\e[1m\e[39m    docker compose stop \n \e[0m"