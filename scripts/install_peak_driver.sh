#!/bin/bash
# Blueberry S4 - PEAK USB-CAN 驱动编译安装脚本
# 需要 sudo 权限

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    echo "   sudo bash scripts/install_peak_driver.sh"
    exit 1
fi

cd /tmp

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PEAK USB-CAN 驱动编译安装${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 1. 安装依赖
echo -e "${YELLOW}[1/7] 安装编译依赖...${NC}"
apt update -qq
apt install -y build-essential linux-headers-$(uname -r) wget

# 2. 下载驱动
echo ""
echo -e "${YELLOW}[2/7] 下载 PEAK 驱动源码...${NC}"
if [ ! -f "peak-linux-driver-8.18.0.tar.gz" ]; then
    wget -q --show-progress https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-8.18.0.tar.gz
fi
echo -e "${GREEN}✓ 下载完成${NC}"

# 3. 解压
echo ""
echo -e "${YELLOW}[3/7] 解压源码...${NC}"
tar -xzf peak-linux-driver-8.18.0.tar.gz
cd peak-linux-driver-8.18.0
echo -e "${GREEN}✓ 解压完成${NC}"

# 4. 清理之前的编译
echo ""
echo -e "${YELLOW}[4/7] 清理之前的编译...${NC}"
make clean 2>/dev/null || true

# 5. 编译 (SocketCAN 模式)
echo ""
echo -e "${YELLOW}[5/7] 编译驱动 (SocketCAN 模式)...${NC}"
echo "   这可能需要几分钟..."
make NET=NETDEV_SUPPORT -j$(nproc) 2>&1 | tail -20
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 编译完成${NC}"

# 6. 安装
echo ""
echo -e "${YELLOW}[6/7] 安装驱动...${NC}"
make install
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ 安装失败${NC}"
    exit 1
fi
echo -e "${GREEN}✓ 安装完成${NC}"

# 7. 加载驱动
echo ""
echo -e "${YELLOW}[7/7] 加载驱动...${NC}"

# 先卸载可能冲突的驱动
rmmod pcan 2>/dev/null || true

# 加载 SocketCAN 基础模块
modprobe can
modprobe can_raw
modprobe can_dev

# 加载新编译的 peak_usb
modprobe peak_usb

if lsmod | grep -q "^peak_usb"; then
    echo -e "${GREEN}✓ peak_usb 驱动加载成功！${NC}"
else
    echo -e "${RED}✗ 驱动加载失败${NC}"
    exit 1
fi

# 等待设备初始化
sleep 2

# 8. 查找新接口
echo ""
echo -e "${YELLOW}查找新的 CAN 接口...${NC}"
NEW_CAN=""
for iface in can0 can1 can2 can3 can4 can5; do
    if ip link show $iface &>/dev/null; then
        DRIVER=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
        if [ "$DRIVER" = "peak_usb" ]; then
            NEW_CAN=$iface
            break
        fi
    fi
done

if [ -n "$NEW_CAN" ]; then
    echo -e "${GREEN}✓ 找到 PEAK USB-CAN 接口: $NEW_CAN${NC}"
    
    # 配置接口
    ip link set $NEW_CAN down 2>/dev/null || true
    ip link set $NEW_CAN type can bitrate 500000
    ip link set $NEW_CAN up
    
    echo -e "${GREEN}✓ $NEW_CAN 已启用${NC}"
    ip -br addr show $NEW_CAN
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  安装成功！${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "测试命令:"
    echo "  candump $NEW_CAN &"
    echo "  cansend $NEW_CAN 123#DEADBEEF"
    echo ""
    echo "启动机器人:"
    echo "  ros2 launch bringup robot.launch.py can_agv_interface:=$NEW_CAN"
else
    echo -e "${YELLOW}⚠ 未找到 PEAK USB-CAN 接口，请检查 USB 连接${NC}"
    echo "可用的 CAN 接口:"
    ip link show type can 2>/dev/null || echo "无"
fi

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
