#!/bin/bash
# Blueberry S4 - 停止机器人脚本

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${YELLOW}🛑 停止 Blueberry S4 机器人...${NC}"
echo ""

# 查找并停止相关进程
PIDS=$(pgrep -f "ros2 launch bringup" || true)
if [ -n "$PIDS" ]; then
    echo "停止 launch 进程..."
    kill $PIDS 2>/dev/null || true
fi

PIDS=$(pgrep -f "can_bridge_py" || true)
if [ -n "$PIDS" ]; then
    echo "停止 CAN 桥接节点..."
    kill $PIDS 2>/dev/null || true
fi

PIDS=$(pgrep -f "teleop_keyboard" || true)
if [ -n "$PIDS" ]; then
    echo "停止键盘遥控节点..."
    kill $PIDS 2>/dev/null || true
fi

echo ""
echo -e "${GREEN}✅ 机器人已停止${NC}"
echo ""
