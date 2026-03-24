#!/bin/bash
# Jetson 环境预检查脚本
# 检查是否安全部署 S4 项目

echo "╔════════════════════════════════════════════════════════╗"
echo "║     S4 项目 - Jetson 环境安全检查                      ║"
echo "║     ⚠️  确保不影响其他同事的项目                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

WARNINGS=0
ERRORS=0

# ==================== 检查 1: 现有 ROS2 工作空间 ====================
echo "📁 [1/8] 检查现有 ROS2 工作空间..."

WORKSPACES=(
    "$HOME/ros2_ws"
    "$HOME/workspace"
    "$HOME/catkin_ws"
    "$HOME/colcon_ws"
)

EXISTING_WS=""
for ws in "${WORKSPACES[@]}"; do
    if [ -d "$ws" ]; then
        echo "   ⚠️  发现现有工作空间: $ws"
        EXISTING_WS="$ws"
        ((WARNINGS++))
    fi
done

if [ -z "$EXISTING_WS" ]; then
    echo "   ✅ 未发现现有 ROS2 工作空间"
else
    echo ""
    echo "   💡 建议: 使用 ~/s4_ws 作为独立工作空间"
fi
echo ""

# ==================== 检查 2: 正在运行的 ROS2 节点 ====================
echo "🔄 [2/8] 检查正在运行的 ROS2 节点..."

if pgrep -x "ros2" > /dev/null || pgrep -f "ros2 launch" > /dev/null; then
    echo "   ⚠️  发现正在运行的 ROS2 进程:"
    pgrep -a "ros2" | head -5
    ((WARNINGS++))
else
    echo "   ✅ 未发现运行中的 ROS2 进程"
fi
echo ""

# ==================== 检查 3: CAN 接口状态 ====================
echo "📡 [3/8] 检查 CAN 接口..."

CAN_INTERFACES=(can0 can1 can2)
for iface in "${CAN_INTERFACES[@]}"; do
    if ip link show "$iface" &> /dev/null; then
        STATE=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}')
        echo "   • $iface: $STATE"
        
        if [ "$STATE" == "UP" ]; then
            echo "     ⚠️  接口正在使用！"
            ((WARNINGS++))
        fi
    else
        echo "   • $iface: 不存在"
    fi
done
echo ""

# ==================== 检查 4: ROS_DOMAIN_ID 使用 ====================
echo "🔢 [4/8] 检查 ROS_DOMAIN_ID..."

echo "   当前环境: ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0} (默认)"
echo "   S4 项目将使用: ROS_DOMAIN_ID=42"
echo "   ✅ 使用不同 ID，不会冲突"
echo ""

# ==================== 检查 5: 磁盘空间 ====================
echo "💾 [5/8] 检查磁盘空间..."

AVAILABLE=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "$AVAILABLE" -lt 5 ]; then
    echo "   ❌ 磁盘空间不足: ${AVAILABLE}GB (需要 > 5GB)"
    ((ERRORS++))
else
    echo "   ✅ 磁盘空间充足: ${AVAILABLE}GB"
fi
echo ""

# ==================== 检查 6: 内存 ====================
echo "🧠 [6/8] 检查内存..."

TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
AVAILABLE_MEM=$(free -g | awk '/^Mem:/{print $7}')

echo "   总内存: ${TOTAL_MEM}GB"
echo "   可用内存: ${AVAILABLE_MEM}GB"

if [ "$AVAILABLE_MEM" -lt 2 ]; then
    echo "   ⚠️  可用内存较低，运行相机节点可能受影响"
    ((WARNINGS++))
else
    echo "   ✅ 内存充足"
fi
echo ""

# ==================== 检查 7: 网络端口 ====================
echo "🌐 [7/8] 检查常用端口..."

PORTS=(11311 11345 9090 5000 8080)
for port in "${PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "   ⚠️  端口 $port 已被占用"
        ((WARNINGS++))
    fi
done
echo ""

# ==================== 检查 8: 用户权限 ====================
echo "👤 [8/8] 检查用户权限..."

if groups "$USER" | grep -q "dialout"; then
    echo "   ✅ 用户在 dialout 组（可访问串口/CAN）"
else
    echo "   ⚠️  用户不在 dialout 组"
    echo "   运行: sudo usermod -aG dialout $USER"
    ((WARNINGS++))
fi

if [ -w "/sys/class/net" ]; then
    echo "   ✅ 有权限配置网络接口"
else
    echo "   ⚠️  配置 CAN 需要 sudo 权限"
fi
echo ""

# ==================== 总结 ====================
echo "╔════════════════════════════════════════════════════════╗"
echo "║                      检查结果                          ║"
echo "╠════════════════════════════════════════════════════════╣"

if [ $ERRORS -gt 0 ]; then
    echo "║  ❌ 错误: $ERRORS 个                                    ║"
fi

if [ $WARNINGS -gt 0 ]; then
    echo "║  ⚠️  警告: $WARNINGS 个                                   ║"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "║  ✅ 检查通过！可以安全部署                              ║"
else
    echo "║  ⚠️  请处理上述问题后再部署                             ║"
fi

echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ==================== 推荐操作 ====================
echo "📋 推荐部署步骤:"
echo ""
echo "   1. 创建独立工作空间:"
echo "      mkdir -p ~/s4_ws/src"
echo "      cd ~/s4_ws/src"
echo "      ln -s /home/hkclr/Blueberry_s4/src/bringup ."
echo "      ln -s /home/hkclr/Blueberry_s4/src/YUHESEN-FW-MAX ."
echo ""
echo "   2. 编译:"
echo "      cd ~/s4_ws"
echo "      colcon build --symlink-install"
echo ""
echo "   3. 启动（使用隔离环境）:"
echo "      export ROS_DOMAIN_ID=42"
echo "      source ~/s4_ws/install/setup.bash"
echo "      ros2 launch bringup robot.launch.py sim:=true"
echo ""

# 返回状态码
if [ $ERRORS -gt 0 ]; then
    exit 1
else
    exit 0
fi
