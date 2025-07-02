# Aztec Network Prover Node 完整运行教程

基于 [Aztec-Network-Prover-Node](https://github.com/cryptonode-id/Aztec-Network-Prover-Node) 仓库的详细部署指南

## 📋 目录
- [前期准备](#前期准备)
- [硬件要求](#硬件要求)
- [系统环境配置](#系统环境配置)
- [安装依赖](#安装依赖)
- [节点配置](#节点配置)
- [启动运行](#启动运行)
- [监控维护](#监控维护)
- [故障排除](#故障排除)
- [优化调优](#优化调优)

## 🔧 前期准备

### ⚠️ 重要声明
- **这不是为了奖励/激励/空投**：将其作为学习和测试目的
- **使用独立钱包**：如果同时运行Sequencer节点，请使用不同钱包避免Nonce冲突
- **独立服务器**：避免端口冲突，建议使用专用服务器

### 💼 准备材料
1. **VPS服务器**：满足硬件要求的Linux服务器
2. **以太坊钱包**：用于Prover身份和交易签名
3. **RPC端点**：执行层和共识层RPC访问
4. **基础Linux知识**：命令行操作经验

## 💪 硬件要求

### 最低配置要求
| 组件 | 要求 | 推荐 |
|------|------|------|
| **CPU** | 64核心 | 64-128核心 |
| **内存** | 256GB+ | 373GB+ |
| **存储** | 1TB+ SSD | 1.8TB+ NVMe SSD |
| **网络** | 1Gbps | 10Gbps |
| **操作系统** | Ubuntu 20.04+ | Ubuntu 22.04 LTS |

### 推荐服务器提供商
- **Hetzner**: 高性能专用服务器
- **Servarica**: 性价比较高（经常缺货）
- **AWS/GCP**: 云服务器（按需付费）
- **阿里云**: 国内云服务器选择

## 🛠️ 系统环境配置

### 1. 更新系统
```bash
sudo apt-get update && sudo apt-get upgrade -y
```

### 2. 安装基础工具
```bash
sudo apt install curl build-essential wget lz4 automake autoconf tmux htop pkg-config libssl-dev tar unzip git -y
```

### 3. 配置防火墙
```bash
# 允许SSH
sudo ufw allow 22
sudo ufw allow ssh
sudo ufw enable

# 允许Aztec端口
sudo ufw allow 8080
sudo ufw allow 40400
sudo ufw allow 40400/udp
```

### 4. 检查系统资源
```bash
# 检查CPU
nproc
lscpu

# 检查内存
free -h

# 检查磁盘
df -h

# 检查网络
ip addr show
```

## 📦 安装依赖

### 1. 安装Docker

#### 移除旧版本Docker
```bash
sudo apt update -y && sudo apt upgrade -y
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do 
    sudo apt-get remove $pkg; 
done
```

#### 安装官方Docker
```bash
# 添加Docker官方GPG密钥
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 添加Docker官方仓库
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 安装Docker
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 启动Docker服务
sudo systemctl enable docker
sudo systemctl restart docker

# 验证安装
docker --version
sudo docker run hello-world
```

### 2. 安装Aztec工具
```bash
# 下载并安装Aztec CLI
bash -i <(curl -s https://install.aztec.network)

# 添加到PATH
echo 'export PATH="$HOME/.aztec/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 验证安装
aztec -V
```

## ⚙️ 节点配置

### 1. 创建工作目录
```bash
mkdir -p ~/prover
cd ~/prover
```

### 2. 创建环境配置文件
```bash
nano .env
```

添加以下内容（替换为您的实际配置）：
```env
# 服务器公网IP
P2P_IP=YOUR_VPS_IP_ADDRESS

# 以太坊执行层RPC端点
ETHEREUM_HOSTS=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# 共识层RPC端点  
L1_CONSENSUS_HOST_URLS=https://beacon-nd-123-456-789.p2pify.com/YOUR_API_KEY

# Prover私钥（不包含0x前缀）
PROVER_PUBLISHER_PRIVATE_KEY=0xYOUR_PRIVATE_KEY

# Prover地址
PROVER_ID=0xYOUR_WALLET_ADDRESS
```

### 3. 创建Docker Compose配置

#### 基础配置（适合中等配置服务器）
```bash
nano docker-compose.yml
```

```yaml
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
      P2P_ENABLED: "true"
      DATA_DIRECTORY: /data-prover
      P2P_IP: ${P2P_IP}
      DATA_STORE_MAP_SIZE_KB: "134217728"
      ETHEREUM_HOSTS: ${ETHEREUM_HOSTS}
      L1_CONSENSUS_HOST_URLS: ${L1_CONSENSUS_HOST_URLS}
      LOG_LEVEL: info
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_PUBLISHER_PRIVATE_KEY: ${PROVER_PUBLISHER_PRIVATE_KEY}
      NODE_OPTIONS: "--max-old-space-size=102400"
      UV_THREADPOOL_SIZE: "16"
    ports:
      - "8080:8080"
      - "40400:40400"
      - "40400:40400/udp"
    volumes:
      - ./data-prover:/data-prover
    deploy:
      resources:
        limits:
          memory: 120G
          cpus: '32'
        reservations:
          memory: 50G
          cpus: '16'
    restart: unless-stopped
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
      PROVER_AGENT_COUNT: "8"
      PROVER_AGENT_POLL_INTERVAL_MS: "10000"
      PROVER_BROKER_HOST: http://broker:8080
      PROVER_ID: ${PROVER_ID}
      NODE_OPTIONS: "--max-old-space-size=25600"
    deploy:
      resources:
        limits:
          memory: 40G
          cpus: '16'
        reservations:
          memory: 20G
          cpus: '8'
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
      NODE_OPTIONS: "--max-old-space-size=15360"
    deploy:
      resources:
        limits:
          memory: 20G
          cpus: '8'
        reservations:
          memory: 10G
          cpus: '4'
    volumes:
      - ./data-broker:/data-broker
    restart: unless-stopped
    entrypoint: >
      sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --network alpha-testnet --prover-broker'
```

#### 高性能配置（适合大型服务器）
如果您有更强的硬件（256GB+ RAM, 64+ cores），可以使用高性能配置：

```yaml
# 修改关键参数
environment:
  PROVER_AGENT_COUNT: "16"  # 增加Agent数量
  NODE_OPTIONS: "--max-old-space-size=204800"  # Prover Node 200GB
  # Agent: "--max-old-space-size=51200"  # 50GB
  # Broker: "--max-old-space-size=32768"  # 32GB
```

## 🚀 启动运行

### 1. 启动节点
```bash
cd ~/prover

# 启动所有服务
docker compose up -d

# 检查容器状态
docker ps
```

### 2. 验证启动
```bash
# 检查容器状态
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查日志
docker logs -f aztec-prover-prover-node-1
```

### 3. 等待同步
节点启动后需要：
- **下载CRS文件**（首次启动）
- **同步L1区块链**
- **同步L2状态**
- **连接P2P网络**

这个过程可能需要30分钟到几小时。

## 📊 监控维护

### 1. 创建监控脚本
```bash
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "🔍 Aztec Prover监控 - $(date)"
echo "=================================="

# 检查容器状态
echo "📊 容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep aztec-prover

echo ""

# 检查broker连接
echo "🔗 Broker连接:"
if docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health > /dev/null 2>&1; then
    echo "✅ Broker连接正常"
else
    echo "❌ Broker连接失败"
fi

echo ""

# 检查资源使用
echo "💾 系统资源:"
free -h | head -2
df -h / | head -2

echo ""

# 检查最新日志
echo "📋 最新活动:"
docker logs --tail 5 aztec-prover-prover-node-1 2>&1 | grep -E "Generated proof|Job.*completed|Downloaded.*block" | tail -3 || echo "暂无活动"

EOF

chmod +x monitor.sh
```

### 2. 运行监控
```bash
# 单次检查
./monitor.sh

# 持续监控
watch -n 60 './monitor.sh'
```

### 3. 设置定时监控
```bash
# 编辑定时任务
crontab -e

# 添加每小时监控
0 * * * * cd /root/prover && /root/prover/monitor.sh >> /var/log/aztec_monitor.log 2>&1
```

## 🔧 故障排除

### 常见问题及解决方案

#### 1. Broker facade stopped 错误
```bash
# 检查Broker连接
docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health

# 重启服务
docker compose restart

# 完全重启
docker compose down && docker compose up -d
```

#### 2. 内存不足
```bash
# 检查内存使用
free -h
docker stats --no-stream

# 降低Agent数量
sed -i 's/PROVER_AGENT_COUNT: "[0-9]*"/PROVER_AGENT_COUNT: "4"/g' docker-compose.yml
docker compose restart aztec-prover-agent-1
```

#### 3. 网络连接问题
```bash
# 检查端口
netstat -tlnp | grep -E '8080|40400'

# 检查防火墙
sudo ufw status

# 检查P2P连接
docker logs aztec-prover-prover-node-1 | grep -i "connected.*peers"
```

#### 4. 同步缓慢
```bash
# 检查同步状态
docker logs aztec-prover-prover-node-1 | grep -E "Downloaded.*block|sync"

# 检查RPC连接
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' $ETHEREUM_HOSTS
```

### 应急重启脚本
```bash
cat > emergency_restart.sh << 'EOF'
#!/bin/bash
echo "🚨 紧急重启Aztec Prover"
echo "====================="

# 强制停止
docker compose down -v

# 清理
docker system prune -f

# 重新启动
docker compose up -d

echo "等待60秒..."
sleep 60

echo "检查状态:"
docker ps | grep aztec-prover
./monitor.sh

EOF

chmod +x emergency_restart.sh
```

## ⚡ 优化调优

### 1. 根据硬件优化Agent数量
```bash
# 获取CPU核心数
CPU_CORES=$(nproc)
echo "CPU核心数: $CPU_CORES"

# 计算合理的Agent数量（核心数的1/4到1/8）
AGENT_COUNT=$((CPU_CORES / 8))
if [ $AGENT_COUNT -lt 1 ]; then
    AGENT_COUNT=1
fi

echo "建议Agent数量: $AGENT_COUNT"

# 应用配置
sed -i "s/PROVER_AGENT_COUNT: \"[0-9]*\"/PROVER_AGENT_COUNT: \"$AGENT_COUNT\"/g" docker-compose.yml
```

### 2. 内存优化
```bash
# 检查可用内存
TOTAL_MEM_GB=$(free -g | awk 'NR==2{print $2}')
echo "总内存: ${TOTAL_MEM_GB}GB"

# 根据内存分配Node.js堆大小
if [ $TOTAL_MEM_GB -gt 300 ]; then
    PROVER_MEM="204800"  # 200GB
    AGENT_MEM="51200"    # 50GB
    BROKER_MEM="25600"   # 25GB
elif [ $TOTAL_MEM_GB -gt 200 ]; then
    PROVER_MEM="102400"  # 100GB
    AGENT_MEM="25600"    # 25GB
    BROKER_MEM="15360"   # 15GB
else
    PROVER_MEM="51200"   # 50GB
    AGENT_MEM="15360"    # 15GB
    BROKER_MEM="10240"   # 10GB
fi

echo "优化内存分配："
echo "Prover: ${PROVER_MEM}MB"
echo "Agent: ${AGENT_MEM}MB"
echo "Broker: ${BROKER_MEM}MB"
```

### 3. 网络优化
```bash
# 优化网络参数
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_rmem = 4096 87380 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' | sudo tee -a /etc/sysctl.conf

# 应用设置
sudo sysctl -p
```

## 📈 性能监控

### 验证节点工作状态

#### 检查证明生成
```bash
# 查看证明生成日志
docker logs aztec-prover-prover-node-1 | grep -E "Generated proof|Successfully verified"

# 统计证明数量
docker logs aztec-prover-prover-node-1 | grep "Generated proof" | wc -l
```

#### 检查同步状态
```bash
# 查看最新区块
docker logs aztec-prover-prover-node-1 | grep "Downloaded L2 block" | tail -5

# 检查P2P连接数
docker logs aztec-prover-prover-node-1 | grep "Connected to.*peers" | tail -1
```

#### 检查收益
```bash
# 查看提交的证明
docker logs aztec-prover-prover-node-1 | grep -i "submitted"

# 在Sepolia Etherscan查看您的地址
echo "在以下链接查看您的Prover活动:"
echo "https://sepolia.etherscan.io/address/$PROVER_ID"
```

## 🎯 最佳实践

### 1. 安全建议
- 使用专用钱包进行Prover操作
- 定期备份配置文件和私钥
- 使用防火墙限制不必要的端口访问
- 定期更新系统和Docker镜像

### 2. 维护建议
- 每日检查节点状态
- 每周重启服务清理内存
- 定期清理Docker日志
- 监控磁盘空间使用

### 3. 性能建议
- 根据实际硬件调整Agent数量
- 监控资源使用，避免过载
- 使用高速SSD存储
- 确保网络连接稳定

## 📞 支持与社区

### 官方资源
- [Aztec官方文档](https://docs.aztec.network/)
- [GitHub仓库](https://github.com/AztecProtocol/aztec-packages)
- [Discord社区](https://discord.gg/aztec)

### 社区资源
- [Aztec论坛](https://discourse.aztec.network/)
- [Twitter官方](https://twitter.com/aztecprotocol)

---

## 💡 结语

运行Aztec Prover节点是参与零知识证明网络的绝佳方式。通过遵循本教程，您应该能够成功部署和运行一个稳定的Prover节点。

记住：
- **耐心等待同步**：初始同步可能需要较长时间
- **持续监控**：定期检查节点状态和性能
- **社区支持**：遇到问题时积极寻求社区帮助
- **享受学习**：这是学习零知识证明技术的好机会

祝您运行愉快！🚀