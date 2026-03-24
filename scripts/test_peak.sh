#!/bin/bash
# Blueberry S4 - PEAK USB-CAN 测试脚本

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}           🔌 PEAK USB-CAN 诊断测试                     ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 1. USB 设备检查
echo -e "${YELLOW}1. USB 设备检查${NC}"
if lsusb | grep -q "0c72:000c"; then
    echo -e "   ${GREEN}✓ PEAK USB-CAN 已连接${NC}"
    lsusb | grep "PEAK"
else
    echo -e "   ${RED}✗ PEAK USB-CAN 未连接${NC}"
    echo "   请检查 USB 线缆连接"
    exit 1
fi
echo ""

# 2. 驱动状态
echo -e "${YELLOW}2. 驱动状态${NC}"
lsmod | grep -E "^pcan|^peak" | while read line; do
    echo "   $line"
done

if lsmod | grep -q "^pcan"; then
    echo -e "   ${YELLOW}⚠ 当前使用 pcan (chardev) 驱动${NC}"
    echo "     灯不闪是正常的，需要应用程序打开设备"
elif lsmod | grep -q "^peak_usb"; then
    echo -e "   ${GREEN}✓ 使用 peak_usb (SocketCAN) 驱动${NC}"
else
    echo -e "   ${RED}✗ 未加载 CAN 驱动${NC}"
fi
echo ""

# 3. 设备节点
echo -e "${YELLOW}3. 设备节点${NC}"
if [ -e /dev/pcanusb32 ]; then
    echo -e "   ${GREEN}✓ chardev 设备存在: /dev/pcanusb32${NC}"
    ls -la /dev/pcanusb32
else
    echo -e "   ${YELLOW}⚠ chardev 设备不存在${NC}"
fi
echo ""

# 4. CAN 接口
echo -e "${YELLOW}4. CAN 接口${NC}"
ip link show type can 2>/dev/null || echo "   无 CAN 接口"
echo ""

# 5. PEAK 驱动详情
echo -e "${YELLOW}5. PEAK 驱动详情${NC}"
if [ -f /proc/pcan ]; then
    echo "   /proc/pcan 内容:"
    cat /proc/pcan | head -10 | sed 's/^/     /'
else
    echo "   ${YELLOW}⚠ /proc/pcan 不存在${NC}"
fi
echo ""

# 6. 测试选项
echo -e "${YELLOW}6. 可用操作${NC}"
echo ""
echo "   A) 切换到 SocketCAN 模式 (推荐)"
echo "      sudo rmmod pcan"
echo "      sudo modprobe can can_raw can_dev peak_usb"
echo ""
echo "   B) 测试 chardev 设备 (安装 pcan 库后)"
echo "      sudo apt install libpopt-dev"
echo "      # 从 PEAK 官网下载并编译示例程序"
echo ""
echo "   C) 检查当前 CAN 接口"
echo "      candump can0"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 7. 如果找到 CAN 接口，提示测试方法
CAN_UP=$(ip link show type can 2>/dev/null | grep "UP" | awk '{print $2}' | tr -d ':')
if [ -n "$CAN_UP" ]; then
    echo -e "${GREEN}✓ 找到活跃的 CAN 接口: $CAN_UP${NC}"
    echo ""
    echo "   测试 CAN 通信:"
    echo "     终端1: candump $CAN_UP"
    echo "     终端2: cansend $CAN_UP 123#DEADBEEF"
    echo ""
    
    # 尝试发送测试帧
    read -p "   是否发送测试帧? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "   发送测试帧到 $CAN_UP..."
        cansend $CAN_UP 123#DEADBEEF
        echo -e "   ${GREEN}✓ 已发送${NC}"
        echo "   如果 PEAK 设备灯闪了一下，说明硬件正常"
    fi
else
    echo -e "${YELLOW}⚠ 没有活跃的 CAN 接口${NC}"
    echo "   运行以下命令设置:"
    echo "     bash scripts/setup_peak_auto.sh"
fi

echo ""
