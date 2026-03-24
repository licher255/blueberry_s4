#!/bin/bash
# S4 - 工作空间检查脚本

echo "╔════════════════════════════════════════════════════════╗"
echo "║          S4 - 工作空间检查                             ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

cd "$(dirname "$0")/.."

# 检查目录结构
echo "📁 目录结构:"
for dir in src config scripts docs; do
    if [ -d "$dir" ]; then
        echo "   ✅ $dir/"
    else
        echo "   ❌ $dir/ (缺失)"
    fi
done
echo ""

# 检查 ROS2 包
echo "📦 ROS2 包:"
for pkg in bringup YUHESEN-FW-MAX; do
    if [ -d "src/$pkg" ]; then
        echo "   ✅ $pkg"
    else
        echo "   ❌ $pkg (缺失)"
    fi
done
echo ""

# 检查编译状态
echo "🔨 编译状态:"
if [ -d "install" ]; then
    echo "   ✅ 已编译"
    if [ -f "install/setup.bash" ]; then
        echo "   ✅ 可 source"
    fi
else
    echo "   ❌ 未编译"
    echo "   运行: bash scripts/build.sh"
fi
echo ""

# 检查依赖
echo "🔍 依赖检查:"
if command -v ros2 &> /dev/null; then
    echo "   ✅ ROS2 已安装"
else
    echo "   ❌ ROS2 未安装"
fi

if command -v python3 &> /dev/null; then
    PYTHON_VER=$(python3 --version | cut -d' ' -f2)
    echo "   ✅ Python $PYTHON_VER"
fi

if python3 -c "import can" 2>/dev/null; then
    echo "   ✅ python-can 已安装"
else
    echo "   ❌ python-can 未安装"
    echo "   安装: pip3 install python-can"
fi
echo ""

# 检查 CAN 接口
echo "📡 CAN 接口:"
for iface in can0 can1; do
    if ip link show $iface &> /dev/null; then
        STATE=$(ip -br link show $iface | awk '{print $2}')
        echo "   ✅ $iface ($STATE)"
    else
        echo "   ❌ $iface (不存在)"
    fi
done
echo ""

echo "📝 下一步建议:"
echo ""
if ! command -v ros2 &> /dev/null; then
    echo "   1. 安装 ROS2:"
    echo "      bash scripts/setup_ros2_env.sh"
elif [ ! -d "install" ]; then
    echo "   1. 编译工作空间:"
    echo "      bash scripts/build.sh"
else
    echo "   1. 加载环境:"
    echo "      source install/setup.bash"
    echo ""
    echo "   2. 启动机器人:"
    echo "      ros2 launch bringup robot.launch.py"
fi
echo ""
