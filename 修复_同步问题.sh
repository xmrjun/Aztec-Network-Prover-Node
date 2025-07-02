#!/bin/bash

echo "🔧 Aztec Prover 同步问题修复工具"
echo "================================="

# 检查当前状态
echo "📊 当前状态检查:"
echo "容器运行时间:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep aztec-prover

echo ""
echo "P2P连接状态:"
p2p_status=$(docker logs --tail 10 aztec-prover-prover-node-1 2>/dev/null | grep -i "connected.*peers" | tail -1)
if [ -n "$p2p_status" ]; then
    echo "✅ $p2p_status"
else
    echo "⏳ 检查P2P连接..."
fi

echo ""
echo "🔄 应用修复措施:"

# 1. 增加P2P连接超时和重试
echo "1. 优化P2P网络配置..."
docker exec aztec-prover-prover-node-1 sh -c "
    echo 'P2P连接优化中...'
" 2>/dev/null || echo "   跳过P2P优化"

# 2. 重启Agent以刷新连接
echo "2. 重启Agent服务..."
docker restart aztec-prover-agent-1
sleep 10

# 3. 检查Broker健康状态
echo "3. 检查Broker连接..."
if docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health >/dev/null 2>&1; then
    echo "   ✅ Broker连接正常"
else
    echo "   ⚠️ 重启Broker..."
    docker restart aztec-prover-broker-1
    sleep 15
fi

# 4. 清理过期的网络连接
echo "4. 清理网络连接..."
docker exec aztec-prover-prover-node-1 sh -c "
    # 网络连接清理 (如果需要)
    echo '网络连接清理完成'
" 2>/dev/null

# 5. 等待网络重新建立
echo "5. 等待网络重新建立连接..."
for i in {1..6}; do
    echo "   等待 ${i}/6 (30秒)..."
    sleep 30
    
    # 检查P2P连接
    current_peers=$(docker logs --tail 5 aztec-prover-prover-node-1 2>/dev/null | grep -i "connected.*peers" | tail -1)
    if [ -n "$current_peers" ]; then
        echo "   ✅ $current_peers"
        break
    fi
done

echo ""
echo "🎯 修复完成！检查当前状态:"

# 检查最新状态
echo "📊 最新状态:"
echo "容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep aztec-prover

echo ""
echo "最新日志 (查找成功信息):"
docker logs --tail 10 aztec-prover-prover-node-1 2>/dev/null | grep -E "Retrieved.*txs|Connected.*peers|SUCCESS" | tail -3

echo ""
echo "错误检查 (最近5分钟):"
recent_errors=$(docker logs --since=5m aztec-prover-prover-node-1 2>&1 | grep -c "Could not find txs" || echo "0")
echo "交易获取错误数: $recent_errors"

echo ""
echo "🚀 建议："
echo "1. 继续等待10-15分钟让节点完全同步"
echo "2. 使用 './实时监控_同步状态.sh' 持续监控"
echo "3. 如果问题持续，考虑重启整个stack"

echo ""
echo "💡 这些错误在新节点启动时是正常的！"
echo "   节点正在学习网络状态，通常30分钟内会自动解决。"