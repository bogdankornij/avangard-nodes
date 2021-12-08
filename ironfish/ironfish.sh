curl -s https://raw.githubusercontent.com/bogdankornij/avangard-nodes/master/docker.sh | bash
echo "alias ironfish='docker exec ironfish ./bin/run'" >> ~/.bashrc && source ~/.bashrc
tee <<EOF >/dev/null $HOME/docker-compose.yaml
version: "3.3"
services:
 ironfish:
  container_name: ironfish
  image: ghcr.io/iron-fish/ironfish:latest
  restart: always
  network_mode: "host"
  entrypoint: sh -c "apt update > /dev/null && apt install curl -y > /dev/null; ./bin/run start"
  healthcheck:
   test: "curl -s -H 'Connection: Upgrade' -H 'Upgrade: websocket' http://127.0.0.1:9033 || killall5 -9"
   interval: 180s
   timeout: 180s
   retries: 3
  volumes:
   - $HOME/.ironfish:/root/.ironfish
 ironfish-miner:
  depends_on:
   - ironfish
  container_name: ironfish-miner
  image: ghcr.io/iron-fish/ironfish:latest
  command: miners:start --threads=-1
  network_mode: "host"
  restart: always
  volumes:
   - $HOME/.ironfish:/root/.ironfish
EOF
docker-compose up -d && docker-compose logs -f --tail=100
