#!/bin/bash
# Blueberry S4 - 一键运行脚本 (CAN设置 + 启动机器人)
# Usage: bash scripts/run.sh [sim|hw|teleop]
#
# 这是推荐的启动方式，会自动处理所有前置步骤

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MODE="${1:-hw}"

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}              🫐 Blueberry S4 一键运行                  ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 步骤 1: 配置 CAN (非仿真模式)
if [ "$MODE" != "sim" ]; then
    echo -e "${BLUE}[1/2] 配置 CAN 设备...${NC}"
    echo ""
    
    # 检查是否有 root 权限
    if [ "$EUID" -eq 0 ]; then
        bash "$SCRIPT_DIR/can_manager.sh" auto
    else
        # 检查 CAN 状态
        CAN_STATUS=$(bash "$SCRIPT_DIR/can_manager.sh" status 2>&1)
        
        if echo "$CAN_STATUS" | grep -q "UP"; then
            echo -e "${GREEN}✅ CAN 设备已就绪${NC}"
        else
            echo -e "${YELLOW}⚠️  CAN 设备需要配置${NC}"
            echo ""
            read -p "   是否使用 sudo 配置 CAN? (Y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                sudo bash "$SCRIPT_DIR/can_manager.sh" auto
            fi
        fi
    fi
    
    echo ""
fi

# 步骤 2: 启动机器人
echo -e "${BLUE}[2/2] 启动机器人...${NC}"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

bash "$SCRIPT_DIR/start_robot.sh" "$MODE"
