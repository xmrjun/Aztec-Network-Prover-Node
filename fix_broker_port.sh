#!/bin/bash

echo "🔧 修复Broker端口配置 - $(date)"
echo "=================================================="

echo ""
echo "🔍 问题诊断:"
echo "   当前 aztec-prover-agent-1 连接端口: 8080 (错误)"
echo "   正确的 broker 端口应该是: 8081"

echo ""
echo "📊 当前agent配置:"
docker exec aztec-prover-agent-1 env | grep BROKER

echo ""
echo "🔧 解决方案选项:"
echo "   选项1: 重启 prover-agent-1 (它有正确的8081端口配置)"
echo "   选项2: 修改 aztec-prover-agent-1 的端口配置"

echo ""
echo "推荐: 重启 prover-agent-1 (因为它已经有正确配置)"
echo ""
echo "是否重启 prover-agent-1 ? (y/N)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo "🔄 重启 prover-agent-1 ..."
    
    echo ""
    echo "1️⃣ 停止当前的 aztec-prover-agent-1..."
    docker stop aztec-prover-agent-1
    
    echo ""
    echo "2️⃣ 启动 prover-agent-1 (正确的8081端口)..."
    docker start prover-agent-1 || docker run -d --name prover-agent-1 \
        -e PROVER_BROKER_HOST=http://162.120.19.25:8081 \
        -e PROVER_AGENT_POLL_INTERVAL_MS=10000 \
        -e PROVER_ID=0x5bfc30c616173a090b69e5a855d8f5d7b6c86efc \
        aztecprotocol/aztec:latest sh -c 'node --no-warnings /usr/src/yarn-project/aztec/dest/bin/index.js start --prover'
    
    echo ""
    echo "3️⃣ 等待启动..."
    sleep 10
    
    echo ""
    echo "4️⃣ 验证配置:"
    echo "   新的broker配置:"
    docker exec prover-agent-1 env | grep BROKER
    
    echo ""
    echo "5️⃣ 测试连接:"
    docker exec prover-agent-1 bash -c "curl -f http://162.120.19.25:8081/health && echo ' ✅ 连接成功' || echo ' ❌ 连接失败'"
    
    echo ""
    echo "6️⃣ 检查容器状态:"
    docker ps | grep agent
    
    echo ""
    echo "✅ 端口修复完成!"
    
else
    echo ""
    echo "❌ 修复已取消"
    echo ""
    echo "📋 手动修复选项:"
    echo "   1. 重启正确配置的agent: docker start prover-agent-1"
    echo "   2. 停止错误配置的agent: docker stop aztec-prover-agent-1"
    echo "   3. 测试连接: curl http://162.120.19.25:8081/health"
fi

echo ""
echo "=================================================="
echo "🔧 端口修复脚本完成 - $(date)"