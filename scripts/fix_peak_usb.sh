#!/bin/bash
# Blueberry S4 - PEAK USB-CAN SocketCAN 修复脚本
# 需要 sudo 权限

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PEAK USB-CAN SocketCAN 修复${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 1. 检查 USB 设备
echo -e "${YELLOW}[1/6] 检查 USB 设备...${NC}"
if ! lsusb | grep -q "0c72:000c"; then
    echo -e "${RED}✗ PEAK USB-CAN 未连接${NC}"
    exit 1
fi
echo -e "${GREEN}✓ PEAK USB-CAN 已连接${NC}"
lsusb | grep PEAK

# 2. 卸载 pcan 驱动
echo ""
echo -e "${YELLOW}[2/6] 卸载 pcan (chardev) 驱动...${NC}"
if lsmod | grep -q "^pcan"; then
    rmmod pcan
    echo -e "${GREEN}✓ pcan 已卸载${NC}"
else
    echo -e "${GREEN}✓ pcan 未加载${NC}"
fi

# 3. 加载 SocketCAN 驱动
echo ""
echo -e "${YELLOW}[3/6] 加载 SocketCAN 驱动...${NC}"
modprobe can
modprobe can_raw
modprobe can_dev

# 4. 尝试加载 peak_usb
echo ""
echo -e "${YELLOW}[4/6] 加载 peak_usb 驱动...${NC}"
if modprobe peak_usb 2>/dev/null; then
    echo -e "${GREEN}✓ peak_usb 加载成功${NC}"
else
    echo -e "${RED}✗ peak_usb 加载失败${NC}"
    echo ""
    echo -e "${YELLOW}可能原因:${NC}"
    echo "  1. 驱动未安装 - 需要安装 linux-can 包"
    echo "  2. 固件问题 - PEAK 设备需要特定固件"
    echo "  3. 内核版本不兼容"
    echo ""
    echo -e "${YELLOW}尝试安装驱动:${NC}"
    echo "  sudo apt update"
    echo "  sudo apt install -y linux-modules-extra-\$(uname -r)"
    exit 1
fi

# 5. 等待设备初始化
echo ""
echo -e "${YELLOW}[5/6] 等待设备初始化 (2秒)...${NC}"
sleep 2

# 6. 检查新接口
echo ""
echo -e "${YELLOW}[6/6] 检查新 CAN 接口...${NC}"
NEW_CAN=""
for iface in can0 can1 can2 can3 can4 can5; do
    if ip link show $iface &>/dev/null; then
        DRIVER=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
        if [ "$DRIVER" = "peak_usb" ]; then
            NEW_CAN=$iface
            echo -e "${GREEN}✓ 找到 PEAK USB-CAN 接口: $iface${NC}"
            break
        fi
    fi
done

if [ -z "$NEW_CAN" ]; then
    echo -e "${RED}✗ 未找到 PEAK USB-CAN 接口${NC}"
    echo ""
    echo -e "${YELLOW}所有 CAN 接口:${NC}"
    for iface in can0 can1 can2 can3 can4 can5; do
        if ip link show $iface &>/dev/null; then
            DRIVER=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
            echo "  $iface - 驱动: $DRIVER"
        fi
    done
    exit 1
fi

# 7. 配置接口
echo ""
echo -e "${YELLOW}配置 $NEW_CAN @ 500000bps...${NC}"
ip link set $NEW_CAN down 2>/dev/null || true
ip link set $NEW_CAN type can bitrate 500000
ip link set $NEW_CAN up

if ip link show $NEW_CAN | grep -q "UP"; then
    echo -e "${GREEN}✓ $NEW_CAN 已启用${NC}"
    ip -br addr show $NEW_CAN
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  修复完成！${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "使用以下命令测试:"
    echo "  终端1: candump $NEW_CAN"
    echo "  终端2: cansend $NEW_CAN 123#DEADBEEF"
    echo ""
    echo "启动机器人:"
    echo "  ros2 launch bringup robot.launch.py can_agv_interface:=$NEW_CAN"
else
    echo -e "${RED}✗ $NEW_CAN 启用失败${NC}"
    exit 1
fi
