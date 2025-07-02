# B机器 Aztec Prover 修复建议

## 🔍 问题诊断

基于与A机器的对比，B机器存在以下问题：
1. **交易获取失败** - 无法从P2P网络获取所需交易
2. **同步状态异常** - 可能连接到了错误的节点集群
3. **网络分区** - 可能处于网络孤岛状态

## 🛠️ 修复步骤

### 步骤1: 重启网络连接
```bash
# 重启所有容器以刷新网络连接
cd ~/prover
docker compose down
sleep 30
docker compose up -d

# 等待5分钟让服务完全启动
```

### 步骤2: 强制重新同步
```bash
# 如果重启后仍有问题，清理P2P数据库
docker compose down
sudo rm -rf ./data-prover/p2p/
docker compose up -d
```

### 步骤3: 检查网络配置
```bash
# 验证端口是否正确开放
sudo ufw status
netstat -tlnp | grep -E '8080|40400'

# 检查是否有防火墙阻止
ping 8.8.8.8
```

### 步骤4: 监控修复进度
```bash
# 使用监控脚本观察
./detailed_monitor.sh

# 重点观察这些指标：
# - "Downloaded L2 block" 信息
# - "Check for X txs found" 信息
# - "Connected to X peers" 信息
```

## 🎯 预期结果

修复成功后，B机器应该显示类似A机器的日志：
```
[时间] INFO: archiver Downloaded L2 block XXXXX
[时间] INFO: prover-node:combined-prover-coordination Check for X txs found all in the pool
[时间] INFO: p2p Retrieved X/X txs for block proposal
```

## ⚡ 快速修复脚本

```bash
#!/bin/bash
echo "🔧 B机器快速修复脚本"
echo "===================="

cd ~/prover

echo "1. 停止服务..."
docker compose down

echo "2. 清理P2P缓存..."
sudo rm -rf ./data-prover/p2p/ 2>/dev/null || true

echo "3. 等待30秒..."
sleep 30

echo "4. 重启服务..."
docker compose up -d

echo "5. 等待服务启动..."
sleep 60

echo "6. 检查状态..."
docker ps | grep aztec-prover

echo "7. 检查连接..."
for i in {1..10}; do
    echo "检查第 $i 次..."
    p2p_status=$(docker logs --tail 5 aztec-prover-prover-node-1 2>/dev/null | grep -i "connected.*peers" | tail -1)
    if [ -n "$p2p_status" ]; then
        echo "✅ $p2p_status"
        break
    fi
    sleep 30
done

echo "8. 检查同步状态..."
docker logs --tail 10 aztec-prover-prover-node-1 | grep -E "Downloaded.*block|found.*pool"

echo ""
echo "🎉 修复完成！请继续监控10-15分钟"
```

## 📊 成功指标

修复成功后应该看到：
- ✅ "Downloaded L2 block" 持续出现
- ✅ "Check for X txs found all in the pool" 
- ✅ "Retrieved X/X txs for block proposal"
- ✅ 连接到100个节点
- ❌ 不再出现 "Could not find txs" 错误

## 🚨 如果问题持续

如果上述方法无效，考虑：
1. **完全重新部署** - 删除所有数据重新开始
2. **检查网络环境** - 确认网络连接质量
3. **尝试不同RPC端点** - 更换Ethereum RPC提供商
4. **降低Agent数量** - 减少资源竞争

## 💡 预防措施

为避免将来出现类似问题：
1. **定期重启** - 每周重启一次服务
2. **监控网络质量** - 确保稳定的网络连接
3. **备份配置** - 保存工作的配置文件
4. **版本管理** - 使用稳定的镜像版本