# Aztec-Network-Prover-Node

A step by step to run *Prover Node* on Aztec Network Testnet.
Prover is intended to generates ZK Proofs that attest to roll-up.

### Notes: 
- Running this activity didn't guarantee you an Airdrop/incentivized activity. Do this as a Hobby!
- Use different wallet if you are running Sequncer Nodes, it's not recommended to use the same wallet because there might be a Nonce Issue if both Prover and Sequencer node submits Txs at the same time. Although there is some of node runner still use the same wallet and it still work, it's better to stay on the safe side.
- Also, use different server if you running Sequencer Nodes to avoid port conflict.

### Hardware Recommended Requirements
**RAM** 128 GB

**CPU** 32 Cores

**DISK** 1TB+ SSD

The Prover node uses high resource than the Secuencer Node. If you running on low specs machine, you will likely face an **Error Stopping job due to deadline hit** and **Error: Epoch proving failed: Proving cancelled**. Which means your Provers failing to submit Proof on Epoch because your Hardware can't catch the deadline.

*You can rent servers from Servarica (https://servarica.com). It's likely the Cheapest option per month AFAIK*

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

```sudo ufw allow 22```

```sudo ufw allow ssh```

```sudo ufw enable```

```sudo ufw allow 8080```

```sudo ufw allow 40400```

```sudo ufw allow 40400/udp```

## 4. Run Prover Node
```mkdir prover```

```cd prover```

```nano docker-compose.yml```

### Using Docker Compose

Paste this into the docker-compose.yml :

```
name: aztec-prover
services:
  prover-node:
    image: aztecprotocol/aztec:latest # Always refer to the docs to check that you're using the correct image.
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
#     PROVER_COORDINATION_NODE_URL: " " # this can point to your own validator - or just simply ignore this
      P2P_ENABLED: "true" # Switch to false if you provide a PROVER_COORDINATION_NODE_URL
      DATA_DIRECTORY: /data-prover
      P2P_IP: Your_VPS_IP
      DATA_STORE_MAP_SIZE_KB: "134217728"
      ETHEREUM_HOSTS: http:IP//:8545 # Your Eexecution layer RPC endpoint
      L1_CONSENSUS_HOST_URLS: http:IP//:3500 # Your Consensus layer RPC endpoint
      LOG_LEVEL: info
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_PUBLISHER_PRIVATE_KEY: 0xYourPrivatekey # The node needs to publish proofs to L1. Replace with your private key
    ports:
      - "8080:8080"
      - "40400:40400"
      - "40400:40400/udp"
    volumes:
      - ./data-prover:/data-prover
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --archiver --prover-node'
  agent:
    image: aztecprotocol/aztec:latest # Always refer to the docs to check that you're using the correct image.
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
      PROVER_AGENT_COUNT: "3" # Can be increased if you want more Agents
      PROVER_AGENT_POLL_INTERVAL_MS: "10000" # Just to reduce the log spamming if you're using debug logging.
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_ID: 0xYourAddress # this should be the address corresponding to the PROVER_PUBLISHER_PRIVATE_KEY you set on the node.
    pull_policy: always
    restart: unless-stopped
    volumes:
      - ./data-prover:/data-prover

  broker:
    image: aztecprotocol/aztec:latest # Always refer to the docs to check that you're using the correct image.
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
      ETHEREUM_HOSTS: http:IP//:8545 # Your Execution layer RPC endpoint
      P2P_IP: Your_VPS_IP
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

link: https://sepolia.etherscan.io

*Normally, your node should make 3 txs in every hour as far i know, assuming 22 minutes every Epoch*


