#!/bin/bash
# S4 项目安全部署到 Jetson 脚本

set -e

S4_WS="$HOME/s4_ws"
BLUEBERRY_DIR="/home/hkclr/Blueberry_s4"

echo "╔════════════════════════════════════════════════════════╗"
echo "║     S4 项目 - 安全部署到 Jetson                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# ==================== 步骤 0: 预检查 ====================
echo "🔍 [0/5] 运行环境检查..."
if ! bash "$BLUEBERRY_DIR/scripts/jetson_precheck.sh"; then
    echo ""
    echo "❌ 环境检查未通过，请解决上述问题后再部署"
    exit 1
fi

echo ""
read -p "⚠️  确认要继续部署吗？这会创建 ~/s4_ws 工作空间 (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消部署"
    exit 0
fi

# ==================== 步骤 1: 创建工作空间 ====================
echo ""
echo "📁 [1/5] 创建独立工作空间..."

if [ -d "$S4_WS" ]; then
    echo "   ⚠️  工作空间已存在: $S4_WS"
    read -p "   要删除并重新创建吗？这将丢失所有编译结果 (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   删除旧工作空间..."
        rm -rf "$S4_WS"
    else
        echo "   使用现有工作空间"
    fi
fi

if [ ! -d "$S4_WS" ]; then
    mkdir -p "$S4_WS/src"
    echo "   ✅ 创建: $S4_WS"
fi

# ==================== 步骤 2: 链接源代码 ====================
echo ""
echo "🔗 [2/5] 链接源代码..."

cd "$S4_WS/src"

# 链接 bringup
if [ ! -d "bringup" ]; then
    ln -s "$BLUEBERRY_DIR/src/bringup" .
    echo "   ✅ bringup"
fi

# 链接 YUHESEN-FW-MAX
if [ ! -d "YUHESEN-FW-MAX" ]; then
    ln -s "$BLUEBERRY_DIR/src/YUHESEN-FW-MAX" .
    echo "   ✅ YUHESEN-FW-MAX"
fi

# ==================== 步骤 3: 安装依赖 ====================
echo ""
echo "📦 [3/5] 安装依赖..."

# 检查 python-can
if ! python3 -c "import can" 2>/dev/null; then
    echo "   安装 python-can..."
    pip3 install --user python-can
fi

# 安装可视化工具（可选）
echo ""
read -p "   要安装可视化工具吗？(RViz2, rqt, Foxglove) [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "   安装可视化工具..."
    sudo apt install -y \
        ros-humble-rviz2 \
        ros-humble-rviz-common \
        ros-humble-rqt \
        ros-humble-rqt-common-plugins \
        ros-humble-rqt-graph \
        ros-humble-rqt-topic \
        ros-humble-rqt-console \
        ros-humble-foxglove-bridge
    echo "   ✅ 可视化工具安装完成"
fi

# 检查 ROS2 依赖
cd "$S4_WS"
if command -v rosdep &> /dev/null; then
    echo "   更新 rosdep..."
    rosdep update 2>/dev/null || true
    
    echo "   安装 ROS2 依赖..."
    rosdep install --from-paths src --ignore-src -y 2>/dev/null || {
        echo "   ⚠️  部分依赖安装失败，尝试继续编译..."
    }
else
    echo "   ⚠️  rosdep 未安装，跳过依赖检查"
fi

# ==================== 步骤 4: 编译 ====================
echo ""
echo "🔨 [4/5] 编译工作空间..."

cd "$S4_WS"

# 清理环境变量，确保隔离
unset COLCON_PREFIX_PATH 2>/dev/null || true
unset CMAKE_PREFIX_PATH 2>/dev/null || true

# 编译
colcon build --symlink-install 2>&1 | tee /tmp/s4_build.log

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "   ✅ 编译成功"
else
    echo "   ❌ 编译失败，查看日志: /tmp/s4_build.log"
    exit 1
fi

# ==================== 步骤 5: 创建启动脚本 ====================
echo ""
echo "📝 [5/5] 创建启动脚本..."

cat > "$S4_WS/start_s4.sh" << 'STARTSCRIPT'
#!/bin/bash
# S4 项目启动脚本
# 使用独立的 ROS_DOMAIN_ID=42 避免与其他项目冲突

echo "🚀 启动 S4 项目环境..."
echo ""

# 检查工作空间
if [ ! -d "$HOME/s4_ws/install" ]; then
    echo "❌ 工作空间未编译"
    echo "   请先运行: bash /home/hkclr/Blueberry_s4/scripts/deploy_to_jetson.sh"
    exit 1
fi

# 设置隔离环境
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0

# 加载工作空间
cd "$HOME/s4_ws"
source install/setup.bash

echo "✅ 环境加载完成"
echo ""
echo "配置信息:"
echo "   ROS_DOMAIN_ID: $ROS_DOMAIN_ID"
echo "   工作空间: $HOME/s4_ws"
echo ""
echo "可用命令:"
echo "   ros2 launch bringup robot.launch.py       # 启动完整系统"
echo "   ros2 launch bringup robot.launch.py sim:=true  # 仿真模式"
echo "   ros2 topic list                           # 查看话题"
echo ""

# 检查 CAN 接口
if ip link show can0 &> /dev/null; then
    CAN0_STATE=$(ip -br link show can0 | awk '{print $2}')
    echo "CAN0 状态: $CAN0_STATE"
fi

if ip link show can1 &> /dev/null; then
    CAN1_STATE=$(ip -br link show can1 | awk '{print $2}')
    echo "CAN1 状态: $CAN1_STATE"
fi

echo ""
echo "提示: 输入 'exit' 退出 S4 环境"
echo ""

# 启动交互 shell
exec bash
STARTSCRIPT

chmod +x "$S4_WS/start_s4.sh"
echo "   ✅ 创建: $S4_WS/start_s4.sh"

# 创建停止脚本
cat > "$S4_WS/stop_s4.sh" << 'STOPSCRIPT'
#!/bin/bash
# 停止 S4 项目所有节点

echo "🛑 停止 S4 项目..."

# 停止 ROS2 节点
pkill -f "ros2 launch bringup" 2>/dev/null || true
pkill -f "ros2 run" 2>/dev/null || true

# 关闭 CAN 接口（可选）
# sudo ip link set can0 down 2>/dev/null || true
# sudo ip link set can1 down 2>/dev/null || true

echo "✅ S4 项目已停止"
echo ""
echo "检查现有 ROS2 进程:"
ps aux | grep ros2 | grep -v grep || echo "   无运行中的 ROS2 进程"
STOPSCRIPT

chmod +x "$S4_WS/stop_s4.sh"
echo "   ✅ 创建: $S4_WS/stop_s4.sh"

# ==================== 完成 ====================
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                  ✅ 部署完成！                         ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📁 工作空间: $S4_WS"
echo ""
echo "🚀 启动 S4 项目:"
echo "   source $S4_WS/start_s4.sh"
echo ""
echo "🛑 停止 S4 项目:"
echo "   bash $S4_WS/stop_s4.sh"
echo ""
echo "🧹 完全删除 S4 项目:"
echo "   rm -rf $S4_WS"
echo "   (不会影响其他项目)"
echo ""
echo "📖 查看安全部署指南:"
echo "   cat $BLUEBERRY_DIR/docs/deployment/safe_deployment_guide.md"
echo ""

# ==================== 可选：可视化配置 ====================
echo ""
echo "🎮 可视化工具"
echo ""
echo "   可用的可视化方式:"
echo "   1. RViz2 (本地显示器): rviz2"
echo "   2. Foxglove (Web 远程): ros2 launch foxglove_bridge foxglove_bridge_launch.xml"
echo "   3. rqt_graph: ros2 run rqt_graph rqt_graph"
echo ""
echo "   查看详细指南:"
echo "   cat $BLUEBERRY_DIR/docs/ros2_setup/visualization_tools.md"

# ==================== 远程访问配置 ====================
echo ""
echo "🌐 远程可视化配置"
echo ""

# 创建远程访问启动脚本
cat > "$S4_WS/start_remote_viz.sh" << 'VIZSCRIPT'
#!/bin/bash
# S4 远程可视化启动脚本
# 在你的电脑上通过浏览器访问

echo "🚀 启动 S4 远程可视化..."
echo ""

# 检查环境
if [ ! -d "$HOME/s4_ws/install" ]; then
    echo "❌ 工作空间未编译"
    exit 1
fi

# 加载环境
export ROS_DOMAIN_ID=42
source "$HOME/s4_ws/install/setup.bash"

# 获取 IP 地址
IP=$(hostname -I | awk '{print $1}')
if [ -z "$$IP" ]; then
    IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
fi

echo "📡 Jetson 信息:"
echo "   IP 地址: $IP"
echo "   端口: 8765"
echo ""
echo "💻 在你的电脑上:"
echo "   1. 打开 https://studio.foxglove.dev"
echo "   2. 点击 'Open connection'"
echo "   3. 选择 'Foxglove WebSocket'"
echo "   4. 输入: ws://$IP:8765"
echo ""
echo "🛑 按 Ctrl+C 停止"
echo ""

# 启动 Foxglove Bridge
exec ros2 launch foxglove_bridge foxglove_bridge_launch.xml port:=8765
VIZSCRIPT

chmod +x "$S4_WS/start_remote_viz.sh"
echo "   ✅ 创建: $S4_WS/start_remote_viz.sh"

# 配置防火墙（如果需要）
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q "Status: active"; then
        echo "   配置防火墙..."
        sudo ufw allow 8765/tcp comment 'Foxglove Bridge' || true
        echo "   ✅ 已开放 8765 端口"
    fi
fi

echo ""
echo "🎮 远程可视化使用说明:"
echo ""
echo "   1. 在 Jetson 上启动:"
echo "      ~/s4_ws/start_remote_viz.sh"
echo ""
echo "   2. 在你的电脑浏览器打开:"
echo "      https://studio.foxglove.dev"
echo ""
echo "   3. 输入 Jetson IP: ws://<jetson-ip>:8765"
echo ""
echo "   详细指南:"
echo "   cat $BLUEBERRY_DIR/docs/deployment/remote_access_guide.md"
