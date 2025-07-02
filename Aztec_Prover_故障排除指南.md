# Aztec Prover节点 "Broker facade stopped" 错误故障排除指南

## 🚨 错误症状

您遇到的错误信息：
```
ERROR: prover-client:orchestrator Error thrown when proving job: Error: Broker facade stopped
at BrokerCircuitProverFacade.stop
at async ServerEpochProver.stop
at async EpochProvingJob.run
at async ProverNode.runJob
```

## 🔍 问题分析

"Broker facade stopped" 错误通常表示：
1. **Broker服务意外停止**
2. **资源不足导致服务崩溃**
3. **网络连接问题**
4. **配置错误**
5. **硬件性能不足**

## 🛠️ 诊断步骤

### 步骤1：检查容器状态
```bash
# 检查所有容器状态
docker ps -a

# 检查容器资源使用情况
docker stats --no-stream
```

### 步骤2：检查各服务日志
```bash
# 检查broker日志
docker logs --tail 100 aztec-prover-broker-1

# 检查prover-node日志
docker logs --tail 100 aztec-prover-prover-node-1

# 检查agent日志
docker logs --tail 100 aztec-prover-agent-1

# 实时监控日志
docker logs -f aztec-prover-broker-1
```

### 步骤3：检查系统资源
```bash
# 检查内存使用
free -h

# 检查CPU使用
top -p $(docker inspect --format='{{.State.Pid}}' aztec-prover-prover-node-1)

# 检查磁盘空间
df -h

# 检查系统负载
uptime
```

### 步骤4：检查网络连接
```bash
# 检查端口是否正常监听
netstat -tlnp | grep -E '8080|40400'

# 检查容器间网络连接
docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health || echo "Broker不可达"
```

## 🔧 解决方案

### 解决方案1：重启服务（推荐首先尝试）
```bash
# 停止所有服务
docker compose down

# 清理数据（可选，会丢失同步数据）
# docker compose down -v

# 重新启动
docker compose up -d

# 检查启动状态
docker ps
docker logs -f aztec-prover-prover-node-1
```

### 解决方案2：检查和修复配置
检查您的 `.env` 文件：
```bash
cat .env
```

确保包含正确的配置：
```
P2P_IP=您的VPS_IP地址
ETHEREUM_HOSTS=您的执行层RPC端点
L1_CONSENSUS_HOST_URLS=您的共识层RPC端点
PROVER_PUBLISHER_PRIVATE_KEY=0x您的私钥
PROVER_ID=0x您的地址
```

### 解决方案3：增加资源限制
修改 `docker-compose.yml`，添加资源限制：
```yaml
services:
  prover-node:
    # ... 其他配置
    deploy:
      resources:
        limits:
          memory: 200G
          cpus: '32'
        reservations:
          memory: 100G
          cpus: '16'
    restart: unless-stopped

  broker:
    # ... 其他配置
    deploy:
      resources:
        limits:
          memory: 50G
          cpus: '8'
        reservations:
          memory: 20G
          cpus: '4'
    restart: unless-stopped

  agent:
    # ... 其他配置
    deploy:
      resources:
        limits:
          memory: 50G
          cpus: '8'
        reservations:
          memory: 20G
          cpus: '4'
    restart: unless-stopped
```

### 解决方案4：优化环境变量
在 `docker-compose.yml` 中添加更多环境变量：
```yaml
environment:
  # 现有配置...
  PROVER_AGENT_COUNT: "1"  # 减少agent数量
  PROVER_AGENT_POLL_INTERVAL_MS: "30000"  # 增加轮询间隔
  LOG_LEVEL: "warn"  # 减少日志输出
  NODE_OPTIONS: "--max-old-space-size=65536"  # 增加Node.js内存限制
```

### 解决方案5：清理和重新同步
```bash
# 完全停止服务
docker compose down -v

# 清理Docker缓存
docker system prune -f

# 拉取最新镜像
docker compose pull

# 重新启动
docker compose up -d
```

## 📊 监控和维护

### 持续监控脚本
创建监控脚本 `monitor.sh`：
```bash
#!/bin/bash
while true; do
    echo "=== $(date) ==="
    echo "容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n系统资源:"
    free -h | head -2
    
    echo -e "\n最近错误:"
    docker logs --tail 5 aztec-prover-prover-node-1 2>&1 | grep -i error || echo "无错误"
    
    echo -e "\n检查broker连接:"
    docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health > /dev/null && echo "✅ Broker正常" || echo "❌ Broker不可达"
    
    echo "===================="
    sleep 300  # 每5分钟检查一次
done
```

### 自动重启脚本
创建自动重启脚本 `auto_restart.sh`：
```bash
#!/bin/bash
LOG_FILE="/var/log/aztec_monitor.log"

check_broker() {
    docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health > /dev/null 2>&1
    return $?
}

restart_services() {
    echo "$(date): 检测到broker问题，重启服务..." >> $LOG_FILE
    docker compose down
    sleep 10
    docker compose up -d
    echo "$(date): 服务已重启" >> $LOG_FILE
}

while true; do
    if ! check_broker; then
        echo "$(date): Broker不可达，准备重启..." >> $LOG_FILE
        restart_services
        sleep 60  # 等待服务启动
    fi
    sleep 30  # 每30秒检查一次
done
```

## 🔍 高级诊断

### 检查具体错误原因
```bash
# 查找特定错误模式
docker logs aztec-prover-prover-node-1 2>&1 | grep -A 5 -B 5 "Broker facade stopped"

# 检查内存不足
docker logs aztec-prover-prover-node-1 2>&1 | grep -i "out of memory\|killed"

# 检查网络问题
docker logs aztec-prover-broker-1 2>&1 | grep -i "connection\|timeout\|refused"
```

### 性能调优建议
1. **减少并发**: 将 `PROVER_AGENT_COUNT` 设置为 1 或 2
2. **增加内存**: 确保系统有足够的RAM（推荐256GB+）
3. **使用SSD**: 确保数据目录在高性能存储上
4. **网络优化**: 确保RPC端点稳定且延迟低

## 📞 紧急处理

如果问题持续存在：

1. **立即重启**: `docker compose restart`
2. **完全重置**: `docker compose down -v && docker compose up -d`
3. **检查硬件**: 确保满足最低硬件要求
4. **更换RPC**: 尝试使用不同的以太坊RPC提供商
5. **降级镜像**: 尝试使用较早版本的镜像

## 📝 日志收集

收集完整的诊断信息：
```bash
# 创建诊断报告
mkdir aztec_diagnostics
docker logs aztec-prover-prover-node-1 > aztec_diagnostics/prover-node.log
docker logs aztec-prover-broker-1 > aztec_diagnostics/broker.log
docker logs aztec-prover-agent-1 > aztec_diagnostics/agent.log
docker ps -a > aztec_diagnostics/containers.txt
free -h > aztec_diagnostics/memory.txt
df -h > aztec_diagnostics/disk.txt
cat .env > aztec_diagnostics/config.env
tar -czf aztec_diagnostics.tar.gz aztec_diagnostics/
```

记住：Prover节点需要大量资源，如果硬件不足，建议考虑升级服务器配置。