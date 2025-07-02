#!/bin/bash

# Aztec Prover节点实时监控脚本
# 用于监控节点状态并自动检测问题

echo "🔍 Aztec Prover节点实时监控"
echo "=========================="
echo "按 Ctrl+C 退出监控"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 监控间隔（秒）
INTERVAL=30

# 错误计数器
ERROR_COUNT=0
BROKER_ERROR_COUNT=0

# 日志文件
LOG_FILE="/tmp/aztec_monitor.log"

# 函数：记录日志
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# 函数：检查容器状态
check_containers() {
    local status=$(docker ps --format "{{.Names}}: {{.Status}}" | grep aztec-prover)
    echo -e "${BLUE}📊 容器状态:${NC}"
    echo "$status"
    
    # 检查是否有容器停止
    if echo "$status" | grep -q "Exited"; then
        echo -e "${RED}❌ 发现停止的容器！${NC}"
        log_message "ERROR: 发现停止的容器"
        return 1
    fi
    return 0
}

# 函数：检查broker连接
check_broker() {
    if docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Broker连接正常${NC}"
        BROKER_ERROR_COUNT=0
        return 0
    else
        echo -e "${RED}❌ Broker连接失败${NC}"
        ((BROKER_ERROR_COUNT++))
        log_message "ERROR: Broker连接失败 (连续失败次数: $BROKER_ERROR_COUNT)"
        return 1
    fi
}

# 函数：检查最新错误
check_recent_errors() {
    local recent_errors=$(docker logs --tail 10 aztec-prover-prover-node-1 2>&1 | grep -i "error\|failed\|stopped" | wc -l)
    
    if [ "$recent_errors" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  发现 $recent_errors 个最新错误${NC}"
        
        # 检查是否有broker facade stopped错误
        local broker_errors=$(docker logs --tail 20 aztec-prover-prover-node-1 2>&1 | grep -i "broker facade stopped" | wc -l)
        if [ "$broker_errors" -gt 0 ]; then
            echo -e "${RED}🚨 发现 Broker facade stopped 错误！${NC}"
            log_message "CRITICAL: 发现 Broker facade stopped 错误"
            ((ERROR_COUNT++))
            return 1
        fi
        
        # 显示最新错误
        echo -e "${YELLOW}最新错误信息:${NC}"
        docker logs --tail 5 aztec-prover-prover-node-1 2>&1 | grep -i "error\|failed\|stopped" | tail -3
    else
        echo -e "${GREEN}✅ 无最新错误${NC}"
        ERROR_COUNT=0
    fi
    return 0
}

# 函数：检查系统资源
check_resources() {
    echo -e "${BLUE}💾 系统资源:${NC}"
    
    # 内存使用
    local mem_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    echo "内存使用: $mem_usage"
    
    # 磁盘使用
    local disk_usage=$(df -h / | awk 'NR==2{print $5}')
    echo "磁盘使用: $disk_usage"
    
    # 检查内存是否过高
    local mem_percent=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
    if [ "$mem_percent" -gt 90 ]; then
        echo -e "${RED}⚠️  内存使用过高: ${mem_percent}%${NC}"
        log_message "WARNING: 内存使用过高: ${mem_percent}%"
    fi
}

# 函数：显示同步状态
check_sync_status() {
    echo -e "${BLUE}🔄 同步状态:${NC}"
    local sync_info=$(docker logs --tail 20 aztec-prover-prover-node-1 2>&1 | grep -E "block|epoch|sync" | tail -3)
    if [ -n "$sync_info" ]; then
        echo "$sync_info"
    else
        echo "无同步信息"
    fi
}

# 函数：自动重启服务
auto_restart() {
    echo -e "${YELLOW}🔄 检测到严重问题，准备自动重启...${NC}"
    log_message "INFO: 开始自动重启服务"
    
    cd ~/prover
    docker compose down
    sleep 10
    docker compose up -d
    
    echo -e "${GREEN}✅ 服务已重启，等待60秒后继续监控...${NC}"
    log_message "INFO: 服务重启完成"
    sleep 60
    
    # 重置计数器
    ERROR_COUNT=0
    BROKER_ERROR_COUNT=0
}

# 主监控循环
echo "开始监控... (日志文件: $LOG_FILE)"
log_message "INFO: 开始监控Aztec Prover节点"

while true; do
    clear
    echo -e "${BLUE}🔍 Aztec Prover节点监控 - $(date)${NC}"
    echo "=================================="
    
    # 检查容器状态
    if ! check_containers; then
        ((ERROR_COUNT++))
    fi
    
    echo ""
    
    # 检查broker连接
    if ! check_broker; then
        ((ERROR_COUNT++))
    fi
    
    echo ""
    
    # 检查最新错误
    check_recent_errors
    
    echo ""
    
    # 检查系统资源
    check_resources
    
    echo ""
    
    # 检查同步状态
    check_sync_status
    
    echo ""
    echo "=================================="
    echo -e "错误计数: ${ERROR_COUNT} | Broker错误: ${BROKER_ERROR_COUNT}"
    
    # 自动重启逻辑
    if [ "$ERROR_COUNT" -ge 3 ] || [ "$BROKER_ERROR_COUNT" -ge 3 ]; then
        auto_restart
        continue
    fi
    
    echo -e "${GREEN}下次检查: $INTERVAL 秒后${NC}"
    echo "按 Ctrl+C 退出监控"
    
    sleep "$INTERVAL"
done