#!/bin/bash

echo "🔍 Aztec Prover 实时同步监控"
echo "============================="

while true; do
    clear
    echo "🕒 监控时间: $(date)"
    echo "============================="
    
    # 检查容器状态
    echo "📦 容器状态:"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep aztec-prover | head -3
    
    echo ""
    
    # 检查同步进度
    echo "🔄 同步进度 (最近5条):"
    docker logs --tail 5 aztec-prover-prover-node-1 2>/dev/null | grep -E "L1 block|L2 block|sync|Downloaded" | tail -3
    
    echo ""
    
    # 检查连接状态
    echo "🌐 网络连接:"
    p2p_status=$(docker logs --tail 10 aztec-prover-prover-node-1 2>/dev/null | grep -i "connected.*peers" | tail -1)
    if [ -n "$p2p_status" ]; then
        echo "✅ $p2p_status"
    else
        echo "⏳ 正在连接P2P网络..."
    fi
    
    echo ""
    
    # 检查资源使用
    echo "💾 资源使用:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep aztec-prover | head -3
    
    echo ""
    
    # 检查错误
    echo "⚠️ 最近错误 (如有):"
    recent_errors=$(docker logs --tail 20 aztec-prover-prover-node-1 2>&1 | grep -i -E "error|failed|exception" | tail -2)
    if [ -n "$recent_errors" ]; then
        echo "$recent_errors"
    else
        echo "✅ 无明显错误"
    fi
    
    echo ""
    echo "🔄 每30秒自动刷新 (Ctrl+C 退出)"
    echo "============================="
    
    sleep 30
done