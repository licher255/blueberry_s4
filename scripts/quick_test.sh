#!/bin/bash
# Blueberry S4 - ROS2 快速测试脚本
# 用于验证 ROS2 环境是否正确安装

echo "╔════════════════════════════════════════════════════════╗"
echo "║          Blueberry S4 - ROS2 环境快速测试              ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

# 检查 ROS2 是否安装
echo "🔍 检查 ROS2 安装..."
if ! command -v ros2 &> /dev/null; then
    echo "❌ ROS2 未安装或未 source"
    echo "   请先运行: source /opt/ros/humble/setup.bash"
    exit 1
fi

echo "✅ ROS2 已安装"
echo "   版本: $(ros2 --version 2>/dev/null || echo 'humble')"
echo ""

# 检查工作空间
echo "🔍 检查工作空间..."
WORKSPACE="$HOME/ros2_ws"
if [ -d "$WORKSPACE" ]; then
    echo "✅ 工作空间存在: $WORKSPACE"
else
    echo "⚠️  工作空间不存在，创建中..."
    mkdir -p "$WORKSPACE/src"
    echo "✅ 已创建: $WORKSPACE"
fi
echo ""

# 检查 CAN 接口
echo "🔍 检查 CAN 接口..."
if ip link show can0 &> /dev/null; then
    echo "✅ can0 存在"
    ip -br addr show can0
else
    echo "⚠️  can0 不存在"
fi

if ip link show can1 &> /dev/null; then
    echo "✅ can1 存在"
    ip -br addr show can1
else
    echo "⚠️  can1 不存在"
fi
echo ""

# 提示用户
echo "📝 你可以运行以下命令测试 ROS2:"
echo ""
echo "   # 终端 1: 启动 turtlesim（小乌龟演示）"
echo "   ros2 run turtlesim turtlesim_node"
echo ""
echo "   # 终端 2: 控制小乌龟"
echo "   ros2 run turtlesim turtle_teleop_key"
echo ""
echo "   # 查看话题列表"
echo "   ros2 topic list"
echo ""
echo "🎉 环境检查完成！"
