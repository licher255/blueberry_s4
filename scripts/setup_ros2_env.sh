#!/bin/bash
# Blueberry S4 - ROS2 环境一键安装脚本
# 适用于 Ubuntu 22.04 + ROS2 Humble

set -e  # 遇到错误立即退出

echo "╔════════════════════════════════════════════════════════╗"
echo "║       S4 - ROS2 环境自动安装脚本            ║"
echo "║                Ubuntu 22.04 + Humble                  ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查系统版本
if ! grep -q "Ubuntu 22.04" /etc/os-release; then
    echo -e "${YELLOW}⚠️  警告: 此脚本为 Ubuntu 22.04 设计${NC}"
    read -p "是否继续? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# ========== 步骤 1: 系统更新 ==========
echo ""
echo "📦 [1/8] 更新系统软件包..."
sudo apt update && sudo apt upgrade -y

# ========== 步骤 2: 安装基础依赖 ==========
echo ""
echo "🔧 [2/8] 安装基础依赖..."
sudo apt install -y \
    curl \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    locales

# ========== 步骤 3: 设置 Locale ==========
echo ""
echo "🌐 [3/8] 设置系统 locale..."
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# ========== 步骤 4: 添加 ROS2 源 ==========
echo ""
echo "📡 [4/8] 添加 ROS2 软件源..."
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt update

# ========== 步骤 5: 安装 ROS2 ==========
echo ""
echo "🤖 [5/8] 安装 ROS2 Humble Desktop..."
echo "    这可能需要 10-30 分钟，请耐心等待..."
sudo apt install -y ros-humble-desktop

# ========== 步骤 6: 安装开发工具 ==========
echo ""
echo "🛠️  [6/8] 安装 ROS2 开发工具..."
sudo apt install -y \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-pip \
    python3-argcomplete \
    python3-can

# ========== 步骤 7: 初始化 rosdep ==========
echo ""
echo "⚙️  [7/8] 初始化 rosdep..."
if [ ! -f /etc/ros/rosdep/sources.list.d/20-default.list ]; then
    sudo rosdep init || true
fi
rosdep update || true

# ========== 步骤 8: 环境配置 ==========
echo ""
echo "🔧 [8/8] 配置环境变量..."

# 添加到 .bashrc
if ! grep -q "source /opt/ros/humble/setup.bash" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# ROS2 Humble" >> ~/.bashrc
    echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
fi

# 立即生效
source /opt/ros/humble/setup.bash

# ========== 创建 Blueberry S4 工作空间 ==========
echo ""
echo "🏗️  创建 Blueberry S4 工作空间..."
WORKSPACE="$HOME/ros2_ws"

if [ ! -d "$WORKSPACE" ]; then
    mkdir -p "$WORKSPACE/src"
    cd "$WORKSPACE/src"
    
    # 创建 blueberry_s4 包
    ros2 pkg create s4_control \
        --build-type ament_python \
        --dependencies rclpy std_msgs geometry_msgs \
        --description "S4 Robot Control Package" \
        --license MIT \
        --maintainer-name "Blueberry Team" || true
    
    echo -e "${GREEN}✅ 工作空间已创建: $WORKSPACE${NC}"
else
    echo -e "${YELLOW}⚠️  工作空间已存在: $WORKSPACE${NC}"
fi

# ========== 完成 ==========
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                    ✅ 安装完成！                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "📋 接下来你可以:"
echo ""
echo "   1️⃣  重新加载环境:"
echo "      source ~/.bashrc"
echo ""
echo "   2️⃣  验证安装:"
echo "      ros2 --version"
echo ""
echo "   3️⃣  创建工作空间:"
echo "      cd ~/ros2_ws/src"
echo "      ros2 pkg create my_package --build-type ament_python"
echo ""
echo "📚 查看详细教程:"
echo "      cat ~/Blueberry_s4/docs/ros2_setup/ros2_beginner_guide.md"
echo ""
echo -e "${GREEN}🎉 请重新打开终端或运行: source ~/.bashrc${NC}"
