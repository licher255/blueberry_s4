#!/bin/bash
# AGV测试完整启动脚本
# 一键启动所有必要的服务

set -e  # 遇到错误立即退出

echo "======================================"
echo "   AGV 安全测试控制 - 完整启动脚本"
echo "======================================"

# 配置
WORKSPACE="$HOME/Blueberry_s4"
ROSBRIDGE_PORT="9091"

# CAN 设备映射文件
CAN_MAPPING_FILE="/tmp/s4_can_mapping.conf"

# 获取映射的 CAN 接口
get_can_agv_interface() {
    if [ -f "$CAN_MAPPING_FILE" ]; then
        grep "^can_agv=" "$CAN_MAPPING_FILE" | cut -d'=' -f2
    else
        # 自动检测 PEAK 设备
        for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E "^can" | sort -V); do
            if [ -L "/sys/class/net/$iface/device/driver" ]; then
                local driver=$(readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null)
                if [ "$driver" == "pcan" ]; then
                    echo "$iface"
                    return
                fi
            fi
        done
        echo "can_agv"  # 返回逻辑名作为后备
    fi
}

CAN_INTERFACE=$(get_can_agv_interface)

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查ROS2环境
check_ros2() {
    if ! command -v ros2 &> /dev/null; then
        echo -e "${RED}错误：ROS2未安装或未source${NC}"
        echo "请运行: source /opt/ros/humble/setup.bash"
        exit 1
    fi
}

# 检查CAN接口
check_can() {
    echo -e "\n${YELLOW}[1/5] 检查CAN接口...${NC}"
    
    # 显示检测到的接口
    echo "检测到 AGV CAN 接口: $CAN_INTERFACE"
    
    if ! ip link show "$CAN_INTERFACE" &> /dev/null; then
        echo -e "${RED}CAN接口 $CAN_INTERFACE 不存在${NC}"
        echo "正在尝试配置CAN接口..."
        cd "$WORKSPACE"
        sudo ./scripts/s4 init || {
            echo -e "${RED}CAN配置失败，请手动检查${NC}"
            exit 1
        }
        # 重新检测
        CAN_INTERFACE=$(get_can_agv_interface)
    fi
    
    # 检查CAN状态
    if ip link show "$CAN_INTERFACE" | grep -q "DOWN"; then
        echo "CAN接口已存在但处于DOWN状态，正在启动..."
        sudo ip link set "$CAN_INTERFACE" up
    fi
    
    # 显示驱动信息
    local driver="unknown"
    if [ -L "/sys/class/net/$CAN_INTERFACE/device/driver" ]; then
        driver=$(readlink -f "/sys/class/net/$CAN_INTERFACE/device/driver" 2>/dev/null | xargs basename 2>/dev/null)
    fi
    
    echo -e "${GREEN}✓ CAN接口 $CAN_INTERFACE 已就绪 ($driver)${NC}"
}

# 加载工作空间环境
setup_env() {
    echo -e "\n${YELLOW}[2/5] 加载ROS2工作空间...${NC}"
    source /opt/ros/humble/setup.bash
    
    if [ -f "$WORKSPACE/install/setup.bash" ]; then
        source "$WORKSPACE/install/setup.bash"
        echo -e "${GREEN}✓ 工作空间已加载${NC}"
    else
        echo -e "${RED}错误：工作空间未编译${NC}"
        echo "请先运行: colcon build --symlink-install"
        exit 1
    fi
    
    # 验证接口包可用
    if ! python3 -c "from yhs_can_interfaces.msg import IoCmd" 2>/dev/null; then
        echo -e "${RED}错误：yhs_can_interfaces Python模块不可用${NC}"
        echo "尝试重新构建接口包..."
        cd "$WORKSPACE"
        colcon build --packages-select yhs_can_interfaces --symlink-install
        source "$WORKSPACE/install/setup.bash"
    fi
}

# 停止已有进程
cleanup() {
    echo -e "\n${YELLOW}[3/5] 清理已有进程...${NC}"
    
    # 停止rosbridge
    pkill -f "rosbridge_websocket" 2>/dev/null || true
    
    # 停止AGV节点
    pkill -f "yhs_can_control_node" 2>/dev/null || true
    
    sleep 2
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 启动AGV节点
start_agv() {
    echo -e "\n${YELLOW}[4/5] 启动AGV驱动节点...${NC}"
    
    cd "$WORKSPACE"
    source install/setup.bash
    
    # 启动AGV节点
    ros2 launch bringup robot.launch.py &
    AGV_PID=$!
    
    echo "AGV节点PID: $AGV_PID"
    
    # 等待节点启动
    sleep 3
    
    # 检查节点是否正常运行
    if ! ps -p $AGV_PID > /dev/null; then
        echo -e "${RED}错误：AGV节点启动失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ AGV节点已启动${NC}"
}

# 启动rosbridge
start_rosbridge() {
    echo -e "\n${YELLOW}[5/5] 启动rosbridge (端口:$ROSBRIDGE_PORT)...${NC}"
    
    # 使用相同的shell环境启动rosbridge，确保能访问yhs_can_interfaces
    ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=$ROSBRIDGE_PORT &
    ROSBRIDGE_PID=$!
    
    echo "rosbridge PID: $ROSBRIDGE_PID"
    
    # 等待rosbridge启动
    sleep 3
    
    # 检查rosbridge是否正常运行
    if ! ps -p $ROSBRIDGE_PID > /dev/null; then
        echo -e "${RED}错误：rosbridge启动失败${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ rosbridge已启动${NC}"
}

# 启动web服务器
start_web() {
    echo -e "\n${YELLOW}[可选] 启动Web服务器...${NC}"
    
    cd "$WORKSPACE/web_dashboard"
    
    # 检查是否已有服务器运行
    if lsof -i :8080 &> /dev/null; then
        echo "端口8080已被占用，使用现有服务器"
    else
        python3 -m http.server 8080 &
        WEB_PID=$!
        sleep 1
        echo "Web服务器PID: $WEB_PID"
        echo -e "${GREEN}✓ Web服务器已启动${NC}"
    fi
    
    echo ""
    echo "======================================"
    echo -e "${GREEN}所有服务已启动！${NC}"
    echo "======================================"
    echo ""
    echo "请在浏览器中访问:"
    echo "  http://localhost:8080/agv_test_control.html"
    echo ""
    echo "WebSocket URL: ws://localhost:$ROSBRIDGE_PORT"
    echo ""
    echo "按 Ctrl+C 停止所有服务"
    echo "======================================"
}

# 清理函数
stop_all() {
    echo ""
    echo "正在停止所有服务..."
    pkill -f "rosbridge_websocket" 2>/dev/null || true
    pkill -f "yhs_can_control_node" 2>/dev/null || true
    pkill -f "python3 -m http.server 8080" 2>/dev/null || true
    echo -e "${GREEN}已停止${NC}"
    exit 0
}

# 捕获Ctrl+C
trap stop_all SIGINT SIGTERM

# 主流程
main() {
    cd "$WORKSPACE"
    check_ros2
    check_can
    setup_env
    cleanup
    start_agv
    start_rosbridge
    start_web
    
    # 保持脚本运行
    wait
}

main "$@"
