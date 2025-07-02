#!/bin/bash

echo "🚨 Agent容器快速修复脚本 - $(date)"
echo "=================================================="

echo ""
echo "⚠️  警告：此脚本将重启agent容器，可能会中断正在进行的证明任务"
echo "继续执行吗？(y/N)"
read -r response

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo ""
    echo "1️⃣ 检查当前agent状态..."
    docker stats aztec-prover-agent-1 --no-stream
    
    echo ""
    echo "2️⃣ 重启agent容器..."
    docker restart aztec-prover-agent-1
    
    echo ""
    echo "3️⃣ 等待容器启动..."
    sleep 10
    
    echo ""
    echo "4️⃣ 检查重启后状态..."
    docker ps | grep agent
    docker stats aztec-prover-agent-1 --no-stream
    
    echo ""
    echo "5️⃣ 检查agent日志..."
    docker logs --tail 20 aztec-prover-agent-1
    
    echo ""
    echo "✅ 重启完成！监控资源使用是否恢复正常"
else
    echo "❌ 操作已取消"
fi

echo ""
echo "=================================================="
echo "📝 建议后续操作："
echo "   - 运行 ./detailed_monitor.sh 检查资源使用"
echo "   - 监控 agent 容器是否稳定运行"
echo "   - 如果问题持续，考虑调整容器资源限制"