#!/bin/bash

echo "🔧 B机器双Agent问题修复脚本 - $(date)"
echo "=================================================="

echo ""
echo "📊 当前状态检查:"
echo "   🐳 运行中的agent容器:"
docker ps | grep agent

echo ""
echo "   📈 当前系统负载:"
uptime

echo ""
echo "   💾 容器资源使用:"
docker stats --no-stream | grep agent

echo ""
echo "=================================================="
echo "🔍 问题分析:"
echo "   发现两个agent容器同时运行:"
echo "   - prover-agent-1 (高CPU负载)"
echo "   - aztec-prover-agent-1 (空闲状态)"
echo ""
echo "   推荐解决方案: 停止冲突的 prover-agent-1"

echo ""
echo "⚠️  警告: 这将停止正在执行任务的agent容器"
echo "是否继续? (y/N)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo "🔄 执行修复步骤..."
    
    echo ""
    echo "1️⃣ 检查两个agent的配置差异:"
    echo "   prover-agent-1 环境变量:"
    docker exec prover-agent-1 env | grep -E "PROVER|BROKER" | head -3 2>/dev/null || echo "   无法访问prover-agent-1环境变量"
    
    echo ""
    echo "   aztec-prover-agent-1 环境变量:"
    docker exec aztec-prover-agent-1 env | grep -E "PROVER|BROKER" | head -3
    
    echo ""
    echo "2️⃣ 停止冲突的 prover-agent-1..."
    docker stop prover-agent-1
    
    echo ""
    echo "3️⃣ 等待系统稳定..."
    sleep 10
    
    echo ""
    echo "4️⃣ 检查修复后状态:"
    echo "   当前运行的agent:"
    docker ps | grep agent
    
    echo ""
    echo "   新的系统负载:"
    uptime
    
    echo ""
    echo "   aztec-prover-agent-1 资源使用:"
    docker stats --no-stream aztec-prover-agent-1
    
    echo ""
    echo "5️⃣ 验证网络连接:"
    docker exec aztec-prover-agent-1 bash -c "curl -s http://162.120.19.25:8080/health || echo 'Broker连接测试失败'"
    
    echo ""
    echo "✅ 修复完成!"
    echo ""
    echo "📋 后续建议:"
    echo "   - 运行 ./detailed_monitor.sh 监控状态"
    echo "   - 检查是否有 docker-compose.yml 中的配置冲突"
    echo "   - 如果需要重新启动 prover-agent-1，请先检查配置"
    
else
    echo ""
    echo "❌ 修复已取消"
    echo ""
    echo "📋 手动修复选项:"
    echo "   1. 检查两个agent的配置: docker inspect [container_name]"
    echo "   2. 停止冲突agent: docker stop prover-agent-1"
    echo "   3. 监控资源使用: watch docker stats"
fi

echo ""
echo "=================================================="
echo "🔧 修复脚本完成 - $(date)"