# Aztec-Network-Prover-Node

A step by step to run *Prover Node* on Aztec Network Testnet.
Prover is intended to generates ZK Proofs that attest to rollup integrity that is pivotal to the protocol.

### Notes: 
- If you are here for *rewards/incentive/airdrop* this is not your place. Either it's a Prover node or Sequencer node. Do it as a Hobby!
- Use different wallet if you are running Sequncer Nodes, it's not recommended to use the same wallet because there might be a Nonce Issue if both Prover and Sequencer node submits Txs at the same time.
Although there is some of node runner still use the same wallet and it still work, it's better to avoid any serious problem.
- Also, use different server if you running Sequencer Nodes to avoid port conflict.

### Hardware Minimum Requirements
**RAM** 256 GB+

**CPU** 64 Cores

**DISK** 1TB+ SSD

The Prover node uses a really high resource than the Secuencer Node, you can go with Higher machine specs than my recommended one. 

If you running on low specs machine, you will likely face an **Error Stopping job due to deadline hit** and **Error: Epoch proving failed: Proving cancelled**. 

Which means your Provers failing to submit Proof on Epoch because your Hardware can't catch the Epoch deadline.

*You can rent servers from Servarica (https://servarica.com). it's likely the Cheapest option currently but often ran out stock* 

*Or see Dedicated server from Hetzner (https://www.hetzner.com/dedicated-rootserver/). Good for quality machine*

### 1. Install Dependencies

```sudo apt-get update && sudo apt-get upgrade -y```

```sudo apt install curl build-essential wget lz4 automake autoconf tmux htop pkg-config libssl-dev tar unzip  -y```
```
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable docker
sudo systemctl restart docker
```

## 2. Install Aztec tools

```bash -i <(curl -s https://install.aztec.network)```

```echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc```

```source ~/.bashrc```

Check if you installed successfully, run: aztec -V

## 3. Allow some ports

```
sudo ufw allow 22
sudo ufw allow ssh
sudo ufw enable
sudo ufw allow 8080
sudo ufw allow 40400
sudo ufw allow 40400/udp
```

## 4. Run Prover Node
```mkdir prover```

```cd prover```

### Create .env file

```nano .env```

Paste this inside the .env and fill your data

```
P2P_IP=Your_VPS_IP
ETHEREUM_HOSTS=Your_Execution_Layer_RPC_Endpoint
L1_CONSENSUS_HOST_URLS=Your_Consensus_Layer_RPC_Endpoint
PROVER_PUBLISHER_PRIVATE_KEY=0xYourPrivatekey
PROVER_ID=0xYourAddress
```

Save it, CTRL + XY

### Using Docker Compose

```nano docker-compose.yml```

Paste this into the docker-compose.yml :

```
name: aztec-prover
services:
  prover-node:
    image: aztecprotocol/aztec:latest
    command:
      - node
      - --no-warnings
      - /usr/src/yarn-project/aztec/dest/bin/index.js
      - start
      - --prover-node
      - --archiver
      - --network
      - alpha-testnet
    depends_on:
      broker:
        condition: service_started
        required: true
    environment:
      # PROVER_COORDINATION_NODE_URL: " " # Optional, this can point to your own validator - or just simply ignore this
      P2P_ENABLED: "true"
      DATA_DIRECTORY: /data-prover
      P2P_IP: ${P2P_IP}
      DATA_STORE_MAP_SIZE_KB: "134217728"
      ETHEREUM_HOSTS: ${ETHEREUM_HOSTS}
      L1_CONSENSUS_HOST_URLS: ${L1_CONSENSUS_HOST_URLS}
      LOG_LEVEL: info
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_PUBLISHER_PRIVATE_KEY: ${PROVER_PUBLISHER_PRIVATE_KEY}
    ports:
      - "8080:8080"
      - "40400:40400"
      - "40400:40400/udp"
    volumes:
      - ./data-prover:/data-prover
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --archiver --prover-node'

  agent:
    image: aztecprotocol/aztec:latest
    command:
      - node
      - --no-warnings
      - /usr/src/yarn-project/aztec/dest/bin/index.js
      - start
      - --prover-agent
      - --network
      - alpha-testnet
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --prover-agent'
    environment:
      PROVER_AGENT_COUNT: "3"
      PROVER_AGENT_POLL_INTERVAL_MS: "10000"
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_ID: ${PROVER_ID}
    pull_policy: always
    restart: unless-stopped
    volumes:
      - ./data-prover:/data-prover

  broker:
    image: aztecprotocol/aztec:latest
    command:
      - node
      - --no-warnings
      - /usr/src/yarn-project/aztec/dest/bin/index.js
      - start
      - --prover-broker
      - --network
      - alpha-testnet
    environment:
      DATA_DIRECTORY: /data-broker
      LOG_LEVEL: info
      ETHEREUM_HOSTS: ${ETHEREUM_HOSTS}
      P2P_IP: ${P2P_IP}
    volumes:
      - ./data-broker:/data-broker
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --prover-broker'
```

- Save it by CTRL + XY

- Then, run the Node Docker

```docker compose up -d```

- See the Docker Status

```docker ps```

- Optional: Stop and kill node

```docker compose down -v```

- Restarting the docker

```docker compose down -v && docker compose up -d```

## Useful Command

- Monitoring the Prover logs

```docker logs -f aztec-prover-prover-node-1```

### Check if your prover are working

```docker logs -f aztec-prover-prover-node-1  2>&1 | grep --line-buffered -E 'epoch proved|epoch'```

You will get logs like this:

![image](https://github.com/user-attachments/assets/13ea3461-52fd-49ca-b430-e6497ce3e046)

### Check if you succesfully Submitted Proof of an Epoch

```docker logs -f aztec-prover-prover-node-1  2>&1 | grep --line-buffered -E 'Submitted'```

You will get logs like this:

![image](https://github.com/user-attachments/assets/b8d5da90-3966-4be5-9894-1fcbb44e525d)

### Also you can check your Prover Address on Sepolia Etherscan

Paste your Prover address on: https://sepolia.etherscan.io

![image](https://github.com/user-attachments/assets/88b7dc60-43c0-4d12-973a-9debb49b48d9)

*Thankyou and Enjoy Proving on Aztec Network!*

