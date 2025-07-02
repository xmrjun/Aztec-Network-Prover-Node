#!/bin/bash

echo "🔍 Agent容器诊断脚本 - $(date)"
echo "=================================================="

echo ""
echo "1️⃣ 检查Agent容器实时资源使用："
echo "docker stats aztec-prover-agent-1 --no-stream"
docker stats aztec-prover-agent-1 --no-stream

echo ""
echo "2️⃣ 检查Agent容器内进程列表："
echo "docker exec aztec-prover-agent-1 ps aux --sort=-%cpu | head -10"
docker exec aztec-prover-agent-1 ps aux --sort=-%cpu | head -10

echo ""
echo "3️⃣ 检查Agent容器内存详情："
echo "docker exec aztec-prover-agent-1 free -h"
docker exec aztec-prover-agent-1 free -h

echo ""
echo "4️⃣ 检查Agent容器CPU核心数："
echo "docker exec aztec-prover-agent-1 nproc"
docker exec aztec-prover-agent-1 nproc

echo ""
echo "5️⃣ 检查Agent容器负载："
echo "docker exec aztec-prover-agent-1 uptime"
docker exec aztec-prover-agent-1 uptime

echo ""
echo "6️⃣ 检查容器资源限制："
echo "docker inspect aztec-prover-agent-1 | grep -A5 -B5 'Memory\|Cpu'"
docker inspect aztec-prover-agent-1 | grep -A5 -B5 'Memory\|Cpu'

echo ""
echo "7️⃣ 检查最新的Agent日志（最后50行）："
echo "docker logs --tail 50 aztec-prover-agent-1"
docker logs --tail 50 aztec-prover-agent-1

echo ""
echo "8️⃣ 系统整体资源状况："
echo "free -h && df -h /"
free -h
df -h /

echo ""
echo "=================================================="
echo "🔍 诊断完成 - $(date)"
echo "📝 如果CPU使用率仍显示异常高（>1000%），可能是："
echo "   - Docker stats指标错误"
echo "   - 证明任务过度并行"
echo "   - 内存不足导致swap使用"
echo "   - 建议重启agent容器: docker restart aztec-prover-agent-1"