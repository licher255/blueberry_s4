#!/bin/bash
# Blueberry S4 - PEAK USB-CAN 切换到 SocketCAN 模式

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 sudo 运行${NC}"
    exit 1
fi

echo -e "${BLUE}🔧 PEAK USB-CAN 切换到 SocketCAN 模式${NC}"
echo ""

# 1. 检查当前驱动状态
echo -e "${YELLOW}1. 检查当前 PEAK 驱动状态...${NC}"
lsusb | grep -i peak
lsmod | grep -E "^pcan|^peak" | head -5

# 2. 卸载当前 pcan 驱动
echo -e "${YELLOW}2. 卸载 pcan 驱动...${NC}"
rmmod pcan 2>/dev/null || echo "pcan 未加载"

# 3. 加载 SocketCAN 支持的驱动
echo -e "${YELLOW}3. 加载 SocketCAN 驱动...${NC}"
modprobe can
modprobe can_raw
modprobe can_dev

# 尝试加载 gs_usb (通用 USB-CAN，支持部分 PEAK 设备)
modprobe gs_usb 2>/dev/null || echo "gs_usb 不可用"

# 或者尝试 peak_usb 驱动
modprobe peak_usb 2>/dev/null || echo "peak_usb 不可用"

# 检查是否有新接口创建
sleep 2
echo ""
echo -e "${YELLOW}4. 检查 CAN 接口...${NC}"
ip link show type can

# 4. 如果还是没有新接口，尝试手动创建
echo ""
echo -e "${YELLOW}5. 尝试替代方案...${NC}"

# 检查设备是否被识别为 can 设备
if ls /sys/bus/usb/drivers/peak_usb/ 2>/dev/null | grep -q ":"; then
    echo -e "${GREEN}✅ peak_usb 驱动已识别设备${NC}"
fi

# 列出所有网络接口
echo "当前 CAN 接口:"
ip link show type can

# 6. 检查是否需要手动创建设备
echo ""
echo -e "${YELLOW}📋 诊断信息:${NC}"
echo "   USB 设备: $(lsusb | grep -i peak | head -1)"
echo "   驱动: $(ls /sys/bus/usb/drivers/ | grep -i peak | head -1 || echo '无')"
echo "   设备节点: $(ls /dev/pcan* 2>/dev/null | head -1 || echo '无')"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════${NC}"
echo ""

# 如果有新的 can 接口，启用它
for iface in can0 can1 can2; do
    if ip link show $iface &> /dev/null; then
        if ! ip link show $iface | grep -q "UP"; then
            echo -e "${YELLOW}启用 $iface...${NC}"
            ip link set $iface down 2>/dev/null || true
            ip link set $iface type can bitrate 500000
            ip link set $iface up
            echo -e "${GREEN}✅ $iface 已启用${NC}"
        fi
    fi
done

echo ""
echo -e "${GREEN}完成！${NC}"
echo "如果 still 没有新的 can 接口，PEAK 设备可能需要使用自带的 PCAN-Basic API 而不是 SocketCAN。"
