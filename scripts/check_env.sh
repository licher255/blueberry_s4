#!/bin/bash
# 环境检查脚本

echo "========== AGV测试环境检查 =========="

# 检查ROS2
echo -e "\n1. 检查ROS2..."
if command -v ros2 &> /dev/null; then
    echo "  ✓ ROS2已安装"
    ros2 --version 2>/dev/null || echo "  ROS2版本: humble"
else
    echo "  ✗ ROS2未安装"
    exit 1
fi

# 检查工作空间
echo -e "\n2. 检查工作空间..."
WORKSPACE="$HOME/Blueberry_s4"
if [ -f "$WORKSPACE/install/setup.bash" ]; then
    echo "  ✓ 工作空间已编译"
else
    echo "  ✗ 工作空间未编译"
    echo "  请运行: cd $WORKSPACE && colcon build --symlink-install"
    exit 1
fi

# 加载环境
echo -e "\n3. 加载环境..."
source /opt/ros/humble/setup.bash
source "$WORKSPACE/install/setup.bash"
echo "  ✓ 环境已加载"

# 检查接口包
echo -e "\n4. 检查yhs_can_interfaces..."
if python3 -c "from yhs_can_interfaces.msg import IoCmd, CtrlCmd; print('OK')" 2>/dev/null; then
    echo "  ✓ Python模块可用"
else
    echo "  ✗ Python模块不可用"
    echo "  尝试修复..."
    cd "$WORKSPACE"
    colcon build --packages-select yhs_can_interfaces --symlink-install
    source "$WORKSPACE/install/setup.bash"
    if python3 -c "from yhs_can_interfaces.msg import IoCmd; print('OK')" 2>/dev/null; then
        echo "  ✓ 修复成功"
    else
        echo "  ✗ 修复失败"
        exit 1
    fi
fi

# 检查CAN接口映射
echo -e "\n5. 检查CAN接口..."

# 获取映射的 CAN 接口
can_agv_iface="can_agv"
can_fd_iface="can_fd"
if [ -f "/tmp/s4_can_mapping.conf" ]; then
    can_agv_iface=$(grep "^can_agv=" /tmp/s4_can_mapping.conf | cut -d'=' -f2)
    can_fd_iface=$(grep "^can_fd=" /tmp/s4_can_mapping.conf | cut -d'=' -f2)
fi

# 检查 AGV CAN (PEAK)
if [ -n "$can_agv_iface" ] && ip link show "$can_agv_iface" &> /dev/null; then
    local driver="unknown"
    if [ -L "/sys/class/net/$can_agv_iface/device/driver" ]; then
        driver=$(readlink -f "/sys/class/net/$can_agv_iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null)
    fi
    echo "  ✓ AGV CAN ($can_agv_iface) 存在 [$driver]"
    if ip link show "$can_agv_iface" | grep -q "UP"; then
        echo "  ✓ AGV CAN 已启动"
    else
        echo "  ⚠ AGV CAN 未启动"
        echo "  请运行: sudo ./scripts/s4 init"
    fi
else
    echo "  ✗ AGV CAN 未找到"
    echo "  请运行: sudo ./scripts/s4 init"
fi

# 检查 Device CAN (ZLG)
if [ -n "$can_fd_iface" ] && ip link show "$can_fd_iface" &> /dev/null; then
    local driver="unknown"
    if [ -L "/sys/class/net/$can_fd_iface/device/driver" ]; then
        driver=$(readlink -f "/sys/class/net/$can_fd_iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null)
    fi
    echo "  ✓ Device CAN ($can_fd_iface) 存在 [$driver]"
    if ip link show "$can_fd_iface" | grep -q "UP"; then
        echo "  ✓ Device CAN 已启动"
    else
        echo "  ⚠ Device CAN 未启动"
    fi
else
    echo "  ⚠ Device CAN 未找到 (ZLG CANFD)"
fi

# 检查占用端口的进程
echo -e "\n6. 检查端口占用..."
if ss -tlnp | grep -q ":9090"; then
    echo "  ⚠ 端口9090被占用:"
    ss -tlnp | grep ":9090"
fi
if ss -tlnp | grep -q ":9091"; then
    echo "  ⚠ 端口9091被占用:"
    ss -tlnp | grep ":9091"
fi
if ss -tlnp | grep -q ":8080"; then
    echo "  ⚠ 端口8080被占用:"
    ss -tlnp | grep ":8080"
fi

echo -e "\n========== 检查完成 =========="
echo ""
echo "使用方式:"
echo "  1. 一键启动: ./scripts/start_agv_test.sh"
echo "  2. 手动启动rosbridge:"
echo "     source install/setup.bash"
echo "     ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9091"
