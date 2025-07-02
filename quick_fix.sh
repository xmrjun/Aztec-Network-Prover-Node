#!/bin/bash

# Aztec Prover节点快速修复脚本
# 用于解决 "Broker facade stopped" 错误

echo "🔧 Aztec Prover节点快速修复脚本"
echo "================================"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查Docker是否可用
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker未安装或不可用${NC}"
    exit 1
fi

# 检查是否在正确的目录
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${YELLOW}⚠️  未找到docker-compose.yml文件${NC}"
    echo "请确保您在包含docker-compose.yml的目录中运行此脚本"
    echo "通常是 ~/prover 目录"
    exit 1
fi

echo -e "${GREEN}✅ 环境检查通过${NC}"

# 函数：检查容器状态
check_containers() {
    echo "📊 检查容器状态..."
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

# 函数：检查系统资源
check_resources() {
    echo "💾 检查系统资源..."
    echo "内存使用情况:"
    free -h
    echo ""
    echo "磁盘使用情况:"
    df -h | grep -E '/$|/var|/tmp'
    echo ""
    echo "系统负载:"
    uptime
}

# 函数：检查broker连接
check_broker() {
    echo "🔗 检查broker连接..."
    if docker exec aztec-prover-prover-node-1 curl -s http://broker:8080/health > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Broker连接正常${NC}"
        return 0
    else
        echo -e "${RED}❌ Broker连接失败${NC}"
        return 1
    fi
}

# 函数：重启服务
restart_services() {
    echo "🔄 重启Aztec Prover服务..."
    
    echo "停止服务..."
    docker compose down
    
    echo "等待5秒..."
    sleep 5
    
    echo "启动服务..."
    docker compose up -d
    
    echo "等待服务启动..."
    sleep 30
    
    echo "检查服务状态..."
    docker ps
}

# 函数：完全重置服务
full_reset() {
    echo "🔄 完全重置Aztec Prover服务..."
    echo -e "${YELLOW}⚠️  这将删除所有同步数据！${NC}"
    read -p "确定要继续吗？(y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "停止并删除所有数据..."
        docker compose down -v
        
        echo "清理Docker缓存..."
        docker system prune -f
        
        echo "拉取最新镜像..."
        docker compose pull
        
        echo "重新启动服务..."
        docker compose up -d
        
        echo "等待服务启动..."
        sleep 60
        
        echo "检查服务状态..."
        docker ps
    else
        echo "操作已取消"
    fi
}

# 函数：收集诊断信息
collect_diagnostics() {
    echo "📋 收集诊断信息..."
    
    DIAG_DIR="aztec_diagnostics_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DIAG_DIR"
    
    echo "收集容器日志..."
    docker logs aztec-prover-prover-node-1 > "$DIAG_DIR/prover-node.log" 2>&1
    docker logs aztec-prover-broker-1 > "$DIAG_DIR/broker.log" 2>&1
    docker logs aztec-prover-agent-1 > "$DIAG_DIR/agent.log" 2>&1
    
    echo "收集系统信息..."
    docker ps -a > "$DIAG_DIR/containers.txt"
    free -h > "$DIAG_DIR/memory.txt"
    df -h > "$DIAG_DIR/disk.txt"
    uptime > "$DIAG_DIR/uptime.txt"
    
    if [ -f ".env" ]; then
        cp .env "$DIAG_DIR/config.env"
    fi
    
    echo "创建压缩包..."
    tar -czf "${DIAG_DIR}.tar.gz" "$DIAG_DIR"
    rm -rf "$DIAG_DIR"
    
    echo -e "${GREEN}✅ 诊断信息已保存到 ${DIAG_DIR}.tar.gz${NC}"
}

# 主菜单
show_menu() {
    echo ""
    echo "请选择操作："
    echo "1) 检查当前状态"
    echo "2) 检查系统资源"
    echo "3) 检查broker连接"
    echo "4) 重启服务"
    echo "5) 完全重置服务（删除数据）"
    echo "6) 收集诊断信息"
    echo "7) 查看实时日志"
    echo "8) 退出"
    echo ""
    read -p "请输入选项 (1-8): " choice
}

# 主循环
while true; do
    show_menu
    case $choice in
        1)
            check_containers
            ;;
        2)
            check_resources
            ;;
        3)
            check_broker
            ;;
        4)
            restart_services
            ;;
        5)
            full_reset
            ;;
        6)
            collect_diagnostics
            ;;
        7)
            echo "选择要查看的日志："
            echo "1) Prover Node"
            echo "2) Broker"
            echo "3) Agent"
            read -p "请选择 (1-3): " log_choice
            case $log_choice in
                1) docker logs -f aztec-prover-prover-node-1 ;;
                2) docker logs -f aztec-prover-broker-1 ;;
                3) docker logs -f aztec-prover-agent-1 ;;
                *) echo "无效选择" ;;
            esac
            ;;
        8)
            echo "退出脚本"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择${NC}"
            ;;
    esac
    
    echo ""
    read -p "按Enter键继续..."
done