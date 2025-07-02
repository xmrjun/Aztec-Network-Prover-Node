#!/bin/bash

echo "🕐 Aztec Prover 1小时证明记录监控"
echo "================================="
echo "开始时间: $(date)"
echo "================================="

# 创建日志文件
LOG_FILE="proof_monitoring_$(date +%Y%m%d_%H%M%S).log"
echo "日志文件: $LOG_FILE"

# 记录初始状态
echo "=== 初始状态 ===" | tee -a $LOG_FILE
echo "时间: $(date)" | tee -a $LOG_FILE
echo "容器状态:" | tee -a $LOG_FILE
docker ps --format "table {{.Names}}\t{{.Status}}" | grep aztec-prover | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE
echo "初始证明统计:" | tee -a $LOG_FILE
initial_proofs=$(docker logs aztec-prover-prover-node-1 2>/dev/null | grep -c "Generated proof" || echo "0")
echo "已生成证明数: $initial_proofs" | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE
echo "=== 开始1小时监控 ===" | tee -a $LOG_FILE

# 1小时监控循环
for i in {1..12}; do
    echo "" | tee -a $LOG_FILE
    echo "=== 检查点 $i/12 - $(date) ===" | tee -a $LOG_FILE
    
    # 检查证明生成
    current_proofs=$(docker logs aztec-prover-prover-node-1 2>/dev/null | grep -c "Generated proof" || echo "0")
    new_proofs=$((current_proofs - initial_proofs))
    echo "证明生成: $new_proofs 个新证明 (总计: $current_proofs)" | tee -a $LOG_FILE
    
    # 检查最新区块
    latest_block=$(docker logs --tail 10 aztec-prover-prover-node-1 2>/dev/null | grep "Downloaded L2 block" | tail -1 | grep -o "block [0-9]*" | grep -o "[0-9]*" || echo "未知")
    echo "最新区块: $latest_block" | tee -a $LOG_FILE
    
    # 检查P2P连接
    p2p_status=$(docker logs --tail 5 aztec-prover-prover-node-1 2>/dev/null | grep -i "connected.*peers" | tail -1 | grep -o "[0-9]* peers" || echo "检查中")
    echo "P2P连接: $p2p_status" | tee -a $LOG_FILE
    
    # 检查资源使用
    cpu_usage=$(docker stats --no-stream --format "{{.CPUPerc}}" aztec-prover-prover-node-1 2>/dev/null || echo "N/A")
    mem_usage=$(docker stats --no-stream --format "{{.MemUsage}}" aztec-prover-prover-node-1 2>/dev/null || echo "N/A")
    echo "资源使用: CPU $cpu_usage, 内存 $mem_usage" | tee -a $LOG_FILE
    
    # 检查最新证明活动
    recent_activity=$(docker logs --tail 20 aztec-prover-prover-node-1 2>/dev/null | grep -E "Generated proof|TUBE_PROOF.*completed|submitted" | tail -2 || echo "暂无新活动")
    if [ "$recent_activity" != "暂无新活动" ]; then
        echo "最新证明活动:" | tee -a $LOG_FILE
        echo "$recent_activity" | tee -a $LOG_FILE
    else
        echo "最新证明活动: 暂无" | tee -a $LOG_FILE
    fi
    
    # 等待5分钟
    if [ $i -lt 12 ]; then
        echo "等待5分钟..." | tee -a $LOG_FILE
        sleep 300
    fi
done

echo "" | tee -a $LOG_FILE
echo "=== 1小时监控完成 - $(date) ===" | tee -a $LOG_FILE

# 最终统计
final_proofs=$(docker logs aztec-prover-prover-node-1 2>/dev/null | grep -c "Generated proof" || echo "0")
total_new_proofs=$((final_proofs - initial_proofs))

echo "" | tee -a $LOG_FILE
echo "📊 1小时监控总结:" | tee -a $LOG_FILE
echo "--------------------------------" | tee -a $LOG_FILE
echo "开始证明数: $initial_proofs" | tee -a $LOG_FILE
echo "结束证明数: $final_proofs" | tee -a $LOG_FILE
echo "新增证明数: $total_new_proofs" | tee -a $LOG_FILE
echo "平均效率: $(echo "scale=2; $total_new_proofs/1" | bc 2>/dev/null || echo "$total_new_proofs") 证明/小时" | tee -a $LOG_FILE

# 检查链上记录
echo "" | tee -a $LOG_FILE
echo "🔗 链上提交记录:" | tee -a $LOG_FILE
submissions=$(docker logs aztec-prover-prover-node-1 2>/dev/null | grep -i -E "submitted|published" | wc -l || echo "0")
echo "链上提交次数: $submissions" | tee -a $LOG_FILE

echo "" | tee -a $LOG_FILE
echo "📁 完整日志已保存到: $LOG_FILE"
echo "🎯 监控完成！"

# 显示关键证明记录
echo ""
echo "🏆 本次监控期间的所有证明记录:"
echo "================================"
docker logs aztec-prover-prover-node-1 2>/dev/null | grep -E "Generated proof|TUBE_PROOF.*completed" | tail -10