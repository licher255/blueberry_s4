#!/bin/bash
# S4 项目功能测试脚本
# 在部署后运行，验证一切正常

echo "╔════════════════════════════════════════════════════════╗"
echo "║           S4 项目 - 功能测试                           ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""

S4_WS="$HOME/s4_ws"
PASSED=0
FAILED=0

# 颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 测试函数
run_test() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Testing $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC}"
        ((FAILED++))
    fi
}

# ==================== 测试 1: 工作空间 ====================
echo "📁 [1/5] 工作空间检查..."

run_test "s4_ws 存在" "[ -d $S4_WS ]"
run_test "install 目录" "[ -d $S4_WS/install ]"
run_test "setup.bash 存在" "[ -f $S4_WS/install/setup.bash ]"
run_test "start_s4.sh 存在" "[ -f $S4_WS/start_s4.sh ]"

echo ""

# ==================== 测试 2: 包结构 ====================
echo "📦 [2/5] 包结构检查..."

run_test "bringup 包" "[ -d $S4_WS/src/bringup ]"
run_test "YUHESEN-FW-MAX 包" "[ -d $S4_WS/src/YUHESEN-FW-MAX ]"
run_test "launch 文件" "[ -f $S4_WS/src/bringup/launch/robot.launch.py ]"

echo ""

# ==================== 测试 3: ROS2 环境 ====================
echo "🤖 [3/5] ROS2 环境检查..."

run_test "ros2 命令" "command -v ros2"
run_test "colcon 命令" "command -v colcon"

# 加载 S4 环境并测试
if [ -f "$S4_WS/install/setup.bash" ]; then
    export ROS_DOMAIN_ID=42
    source "$S4_WS/install/setup.bash"
    run_test "包加载" "ros2 pkg list | grep -q bringup"
fi

echo ""

# ==================== 测试 4: 依赖 ====================
echo "🔧 [4/5] 依赖检查..."

run_test "python-can" "python3 -c 'import can'"
run_test "yaml 模块" "python3 -c 'import yaml'"

echo ""

# ==================== 测试 5: 配置文件 ====================
echo "⚙️  [5/5] 配置文件检查..."

run_test "hardware_profile.yaml" "[ -f /home/hkclr/Blueberry_s4/config/hardware_profile.yaml ]"
run_test "config_loader.py" "[ -f /home/hkclr/Blueberry_s4/config/config_loader.py ]"

echo ""

# ==================== 总结 ====================
echo "╔════════════════════════════════════════════════════════╗"
printf "║  测试结果: ${GREEN}%d 通过${NC}, " $PASSED
if [ $FAILED -gt 0 ]; then
    printf "${RED}%d 失败${NC}\n" $FAILED
else
    printf "${GREEN}0 失败${NC}\n"
fi
echo "╚════════════════════════════════════════════════════════╝"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 所有测试通过！可以安全运行 S4 项目。"
    echo ""
    echo "启动命令:"
    echo "   source ~/s4_ws/start_s4.sh"
    echo "   ros2 launch bringup robot.launch.py sim:=true"
    exit 0
else
    echo "⚠️  部分测试失败，请检查上述问题。"
    echo ""
    echo "建议:"
    echo "   1. 重新部署: bash scripts/deploy_to_jetson.sh"
    echo "   2. 查看日志: cat /tmp/s4_build.log"
    exit 1
fi
