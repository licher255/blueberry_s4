#!/bin/bash
# Blueberry S4 - 状态检查脚本

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}              🫐 Blueberry S4 系统状态                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# ROS2 状态
echo -e "${BLUE}📦 ROS2 状态:${NC}"
if command -v ros2 &> /dev/null; then
    echo -e "   ${GREEN}✅ ROS2 已安装${NC}"
    ros2 --version 2>/dev/null || echo "   版本: humble"
else
    echo -e "   ${RED}❌ ROS2 未安装${NC}"
fi
echo ""

# 工作空间
echo -e "${BLUE}🔨 工作空间:${NC}"
if [ -d "install" ]; then
    echo -e "   ${GREEN}✅ 已编译${NC}"
    echo "   包列表:"
    ls -1 install/ | grep -v "COLCON\|local\|setup" | sed 's/^/     - /'
else
    echo -e "   ${RED}❌ 未编译${NC}"
    echo "   运行: bash scripts/build.sh"
fi
echo ""

# CAN 接口
echo -e "${BLUE}📡 CAN 接口:${NC}"
for iface in can0 can1; do
    if ip link show $iface &> /dev/null; then
        STATE=$(ip -br link show $iface | awk '{print $2}')
        if [[ "$STATE" == *"UP"* ]]; then
            echo -e "   ${GREEN}✅ $iface ($STATE)${NC}"
            # 显示统计
            STATS=$(ip -s link show $iface 2>/dev/null | grep -E "RX|TX" | head -2)
            echo "$STATS" | sed 's/^/      /'
        else
            echo -e "   ${YELLOW}⚠️  $iface ($STATE)${NC}"
        fi
    else
        echo -e "   ${RED}❌ $iface (不存在)${NC}"
    fi
done
echo ""

# 运行中的节点
echo -e "${BLUE}🤖 运行中的节点:${NC}"
NODES=$(pgrep -a -f "ros2|can_bridge|teleop" | grep -v grep | grep -v bash || true)
if [ -n "$NODES" ]; then
    echo "$NODES" | while read line; do
        echo -e "   ${GREEN}●${NC} $line"
    done
else
    echo -e "   ${YELLOW}⚠️  没有运行中的节点${NC}"
fi
echo ""

# 快速操作提示
echo -e "${BLUE}📋 快速操作:${NC}"
echo "   启动:  bash scripts/run.sh"
echo "   停止:  bash scripts/stop_robot.sh"
echo "   设置:  sudo bash scripts/setup_can.sh"
echo ""
