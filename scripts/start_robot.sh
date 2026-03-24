#!/bin/bash
# Blueberry S4 - 一键启动机器人脚本
# Usage: bash scripts/start_robot.sh [sim|hw|teleop]
#
# 启动流程:
# 1. 检查 ROS2 环境
# 2. 检查 CAN 设备 (关键!)
# 3. 自动安装/配置 CAN 驱动
# 4. 编译工作空间
# 5. 启动机器人

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

# 启动模式
MODE="${1:-hw}"  # 默认硬件模式: sim/hw/teleop

# 显示启动横幅
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}              🫐 Blueberry S4 机器人启动器              ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 步骤 1: 检查 ROS2 环境
echo -e "${BLUE}[1/5] 检查 ROS2 环境...${NC}"
if ! command -v ros2 &> /dev/null; then
    if [ -f "/opt/ros/humble/setup.bash" ]; then
        source /opt/ros/humble/setup.bash
        echo -e "${GREEN}✅ ROS2 Humble 已加载${NC}"
    else
        echo -e "${RED}❌ 找不到 ROS2 Humble，请检查安装${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ ROS2 已就绪${NC}"
fi

# 步骤 2: 检查 CAN 设备 (硬件模式)
if [ "$MODE" != "sim" ]; then
    echo ""
    echo -e "${BLUE}[2/5] 检查 CAN 设备...${NC}"
    
    # 使用 can_manager 检查状态
    bash "$SCRIPT_DIR/can_manager.sh" status 2>/dev/null || true
    
    # 检查是否有活跃的 CAN 接口
    ACTIVE_CAN=$(ip -br link show type can 2>/dev/null | grep "UP" | awk '{print $1}' | head -1)
    
    if [ -z "$ACTIVE_CAN" ]; then
        echo ""
        echo -e "${YELLOW}⚠️  没有找到活跃的 CAN 接口${NC}"
        echo -e "${YELLOW}   尝试自动配置...${NC}"
        echo ""
        
        # 检查是否为 root
        if [ "$EUID" -eq 0 ]; then
            bash "$SCRIPT_DIR/can_manager.sh" auto
        else
            echo -e "${YELLOW}   需要 root 权限配置 CAN${NC}"
            echo "   运行: sudo bash scripts/can_manager.sh auto"
            echo ""
            read -p "   是否现在配置? (y/N) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo bash "$SCRIPT_DIR/can_manager.sh" auto
                # 重新检查
                ACTIVE_CAN=$(ip -br link show type can 2>/dev/null | grep "UP" | awk '{print $1}' | head -1)
            else
                echo -e "${YELLOW}   继续启动，但机器人可能无法通信${NC}"
            fi
        fi
    fi
    
    # 显示最终 CAN 状态
    if [ -n "$ACTIVE_CAN" ]; then
        echo ""
        echo -e "${GREEN}✅ CAN 接口就绪: $ACTIVE_CAN${NC}"
    else
        echo ""
        echo -e "${YELLOW}⚠️  警告: CAN 接口未就绪${NC}"
        echo "   仿真模式继续，硬件模式可能失败"
    fi
fi

# 步骤 3: 检查工作空间编译状态
echo ""
echo -e "${BLUE}[3/5] 检查工作空间...${NC}"
NEED_BUILD=false

if [ ! -d "install" ]; then
    echo -e "${YELLOW}⚠️  工作空间未编译${NC}"
    NEED_BUILD=true
else
    # 检查关键包是否存在
    for pkg in bringup fw_max_can; do
        if [ ! -d "install/$pkg" ]; then
            echo -e "${YELLOW}⚠️  包 $pkg 未编译${NC}"
            NEED_BUILD=true
            break
        fi
    done
fi

# 自动编译
if [ "$NEED_BUILD" = true ]; then
    echo -e "${YELLOW}🔨 正在编译工作空间...${NC}"
    bash scripts/build.sh
    echo -e "${GREEN}✅ 编译完成${NC}"
fi

# 步骤 4: 修复 fw_max_can 的 libexec 路径（已知问题）
echo ""
echo -e "${BLUE}[4/5] 检查包配置...${NC}"
if [ -d "install/fw_max_can" ]; then
    if [ ! -d "install/fw_max_can/lib/fw_max_can" ]; then
        echo -e "${YELLOW}🔧 修复 fw_max_can 路径...${NC}"
        mkdir -p install/fw_max_can/lib/fw_max_can
        ln -sf ../../bin/can_bridge_py install/fw_max_can/lib/fw_max_can/can_bridge_py 2>/dev/null || true
        ln -sf ../../bin/teleop_keyboard install/fw_max_can/lib/fw_max_can/teleop_keyboard 2>/dev/null || true
        echo -e "${GREEN}✅ 路径修复完成${NC}"
    else
        echo -e "${GREEN}✅ 包配置正常${NC}"
    fi
fi

# 步骤 5: 加载工作空间环境
echo ""
echo -e "${BLUE}[5/5] 加载工作空间环境...${NC}"
source install/setup.bash
echo -e "${GREEN}✅ 环境加载完成${NC}"

# 确定 CAN 接口
CAN_INTERFACE="${ACTIVE_CAN:-can2}"

# 根据模式启动
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}🤖 启动机器人...${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
echo ""

LAUNCH_ARGS=""

# 修复 xterm 问题 (SSH环境下禁用)
if [ -z "$DISPLAY" ]; then
    echo -e "${YELLOW}⚠️  检测到 SSH 环境，禁用键盘遥控终端${NC}"
fi

case "$MODE" in
    sim)
        echo -e "${BLUE}📟 仿真模式${NC}"
        LAUNCH_ARGS="sim:=true use_teleop:=false"
        ;;
    teleop)
        echo -e "${BLUE}🎮 硬件模式 + 键盘遥控${NC}"
        LAUNCH_ARGS="sim:=false use_agv:=true use_teleop:=true can_agv_interface:=$CAN_INTERFACE"
        ;;
    hw|*)
        echo -e "${BLUE}🔧 硬件模式${NC}"
        echo -e "   CAN 接口: ${CYAN}$CAN_INTERFACE${NC}"
        LAUNCH_ARGS="sim:=false use_agv:=true use_teleop:=false use_whj:=false use_kinco:=false use_cameras:=false use_lidar:=false can_agv_interface:=$CAN_INTERFACE"
        ;;
esac

echo ""
echo -e "${YELLOW}启动参数: $LAUNCH_ARGS${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 启动
ros2 launch bringup robot.launch.py $LAUNCH_ARGS
