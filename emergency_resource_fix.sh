#!/bin/bash

echo "🚨 紧急资源使用修复 - $(date)"
echo "=================================================="

echo ""
echo "📊 当前状态:"
echo "   CPU: 12,494% (极度异常)"
echo "   内存: 172GB/377GB (46%)"
echo "   负载: 408"

echo ""
echo "🔍 检查CPU核心数:"
CORES=$(nproc)
echo "   系统CPU核心数: $CORES"
echo "   理论最大负载建议: $((CORES * 2))"
echo "   当前负载超标: $((408 / CORES))倍"

echo ""
echo "🔧 紧急修复选项:"
echo "   1. 重启agent (清理可能的内存泄漏)"
echo "   2. 检查agent配置"
echo "   3. 暂停agent (如果系统过载)"

echo ""
echo "选择操作:"
echo "   1) 重启agent"
echo "   2) 检查配置" 
echo "   3) 暂停agent"
echo "   4) 取消"
read -p "请选择 (1-4): " choice

case $choice in
    1)
        echo ""
        echo "🔄 重启agent..."
        docker restart prover-agent-1
        
        echo ""
        echo "⏱️ 等待重启..."
        sleep 15
        
        echo ""
        echo "📊 重启后状态:"
        docker stats --no-stream prover-agent-1
        uptime
        ;;
        
    2)
        echo ""
        echo "🔍 检查agent配置:"
        docker exec prover-agent-1 env | grep -E "PROVER|AGENT|BROKER"
        
        echo ""
        echo "📋 建议调整:"
        echo "   - 考虑降低 PROVER_AGENT_COUNT (从20减少到5-10)"
        echo "   - 检查是否有资源限制配置"
        ;;
        
    3)
        echo ""
        echo "⏸️ 暂停agent..."
        docker pause prover-agent-1
        
        echo ""
        echo "📊 暂停后系统状态:"
        uptime
        free -h
        ;;
        
    4)
        echo "❌ 操作已取消"
        ;;
        
    *)
        echo "❌ 无效选择"
        ;;
esac

echo ""
echo "=================================================="
echo "💡 后续建议:"
echo "   - 监控资源使用: watch docker stats"
echo "   - 检查系统日志: docker logs prover-agent-1"
echo "   - 考虑调整并发数量配置"