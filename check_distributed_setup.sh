#!/bin/bash

echo "🌐 分布式Prover架构诊断 - $(date)"
echo "=================================================="

# 获取当前机器信息
HOSTNAME=$(hostname)
echo "🖥️  当前机器: $HOSTNAME"

# 检查本机容器
echo ""
echo "1️⃣ 本机容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 检查容器角色
echo ""
echo "2️⃣ 机器角色分析:"
if docker ps | grep -q "prover-node"; then
    echo "   📍 角色: Complete Node (Coordinator)"
    echo "   ✅ 组件: prover-node + broker + agent"
    
    echo ""
    echo "3️⃣ Coordinator节点检查:"
    echo "   🔗 Broker端口检查:"
    netstat -ln | grep ":8081" && echo "   ✅ Broker端口8081开放" || echo "   ❌ Broker端口8081未开放"
    
    echo "   🔗 Prover端口检查:"
    netstat -ln | grep ":8080" && echo "   ✅ Prover端口8080开放" || echo "   ❌ Prover端口8080未开放"
    
elif docker ps | grep -q "agent"; then
    echo "   📍 角色: Worker Node"
    echo "   ✅ 组件: agent only"
    
    echo ""
    echo "3️⃣ Worker节点配置检查:"
    echo "   🔧 Agent环境变量:"
    docker exec aztec-prover-agent-1 env | grep -i -E "(broker|prover|node)" | head -5
    
    echo ""
    echo "   🔗 Broker连接测试:"
    # 尝试连接常见的broker地址
    for ip in "127.0.0.1" "localhost" "$(hostname -I | awk '{print $1}')" "172.17.0.1"; do
        echo "   Testing $ip:8081..."
        timeout 3 nc -z $ip 8081 && echo "   ✅ $ip:8081 可连接" || echo "   ❌ $ip:8081 不可连接"
    done
else
    echo "   ❓ 未知角色 - 无相关容器运行"
fi

echo ""
echo "4️⃣ 网络配置:"
echo "   🌐 本机IP地址:"
ip addr show | grep -E "inet.*eth|inet.*en" | head -3 | sed 's/^/   /'

echo "   🔗 路由信息:"
ip route | head -3 | sed 's/^/   /'

echo ""
echo "5️⃣ 资源使用状况:"
echo "   💾 内存:"
free -h | head -2 | sed 's/^/   /'

echo "   💽 磁盘:"
df -h / | sed 's/^/   /'

echo "   🖥️  CPU负载:"
uptime | sed 's/^/   /'

echo ""
echo "6️⃣ 容器资源使用:"
if docker ps -q | wc -l | grep -q "0"; then
    echo "   ❌ 无运行中的容器"
else
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
fi

echo ""
echo "=================================================="
echo "🔍 诊断建议:"

if docker ps | grep -q "prover-node"; then
    echo "   📋 作为Coordinator节点:"
    echo "   - 监控资源使用，特别是内存"
    echo "   - 确保8080和8081端口对worker节点开放"
    echo "   - 监控P2P连接状态"
elif docker ps | grep -q "agent"; then
    echo "   📋 作为Worker节点:"
    echo "   - 配置正确的broker地址"
    echo "   - 确保网络连接到coordinator节点"
    echo "   - 监控任务执行效率"
else
    echo "   ⚠️  未检测到Aztec相关容器"
fi

echo ""
echo "🔧 下一步操作:"
echo "   - 运行 ./detailed_monitor.sh 持续监控"
echo "   - 检查docker-compose.yml配置"
echo "   - 验证防火墙和网络安全组设置"