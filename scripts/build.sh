#!/bin/bash
# Blueberry S4 - 编译脚本

set -e

echo "🔨 S4 - 编译工作空间"
echo ""

cd "$(dirname "$0")/.."

# 检查 ROS2 环境
if ! command -v colcon &> /dev/null; then
    echo "❌ 未找到 colcon，请先安装 ROS2"
    echo "   运行: bash scripts/setup_ros2_env.sh"
    exit 1
fi

# 安装依赖
echo "📦 安装依赖..."
rosdep update || true
rosdep install --from-paths src --ignore-src -y || echo "⚠️ 部分依赖安装失败，继续编译..."

# 编译选项
BUILD_ARGS="--symlink-install"

if [ "$1" == "clean" ]; then
    echo "🧹 清理编译目录..."
    rm -rf build install log
fi

if [ "$1" == "select" ]; then
    shift
    echo "🔧 编译指定包: $@"
    BUILD_ARGS="$BUILD_ARGS --packages-select $@"
fi

echo ""
echo "🔨 开始编译..."
echo "   选项: $BUILD_ARGS"
echo ""

colcon build $BUILD_ARGS

echo ""
echo "✅ 编译完成！"
echo ""
echo "加载环境:"
echo "   source install/setup.bash"
