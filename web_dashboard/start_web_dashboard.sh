#!/bin/bash
# Blueberry S4 - Web Dashboard 启动脚本
# 启动 HTTP 服务器和 ROS2 rosbridge_server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  🫐 Blueberry S4 - Web Dashboard${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 获取 IP 地址
IP=$(hostname -I | awk '{print $1}')
if [ -z "$IP" ]; then
    IP=$(ip route get 1 2>/dev/null | awk '{print $7; exit}')
fi

# 加载 ROS2 环境
if [ -f "/opt/ros/humble/setup.bash" ]; then
    source /opt/ros/humble/setup.bash
fi
if [ -f "$PROJECT_DIR/install/setup.bash" ]; then
    source "$PROJECT_DIR/install/setup.bash"
fi

# 检查 rosbridge_server
if ! ros2 pkg list | grep -q rosbridge_server; then
    echo -e "${YELLOW}⚠️  rosbridge_server 未安装${NC}"
    echo "   安装: sudo apt install ros-humble-rosbridge-server"
    exit 1
fi

echo -e "${GREEN}✓ ROS2 环境加载完成${NC}"
echo ""
echo "📡 网络信息:"
echo "   IP 地址: $IP"
echo "   HTTP:    http://$IP:8080"
echo "   WS:      ws://$IP:9090"
echo ""

# 启动 HTTP 服务器
echo "🚀 启动 HTTP 服务器..."
cd "$SCRIPT_DIR"
python3 -m http.server 8080 &
HTTP_PID=$!

# 等待 HTTP 服务器启动
sleep 1

# 启动 rosbridge_server
echo "🚀 启动 ROS2 Bridge..."
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9091 &
BRIDGE_PID=$!

echo ""
echo -e "${GREEN}✓ 服务已启动！${NC}"
echo ""
echo "💻 在你的电脑上打开浏览器:"
echo "   http://$IP:8080"
echo ""
echo "🛑 按 Ctrl+C 停止所有服务"
echo ""

# 捕获 Ctrl+C 停止服务
trap "echo ''; echo 'Stopping services...'; kill $HTTP_PID $BRIDGE_PID 2>/dev/null; exit 0" INT

# 等待
wait
