#!/bin/bash
# ZLG USB-CANFD SocketCAN 驱动安装脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DRIVER_DIR="/home/hkclr/Blueberry_s4/drivers/zlg_usbcanfd_2_10"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  ZLG SocketCAN 驱动安装${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# 检查root权限
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}[ERROR] 请使用 sudo 运行${NC}"
    exit 1
fi

# 检查驱动文件
if [ ! -d "$DRIVER_DIR" ]; then
    echo -e "${RED}[ERROR] 驱动目录不存在: $DRIVER_DIR${NC}"
    echo "请先解压 socketcan 版本驱动到此目录"
    exit 1
fi

cd "$DRIVER_DIR"

# 1. 安装依赖
echo -e "${BLUE}[1/5] 检查依赖...${NC}"
if ! dpkg -l | grep -q "linux-headers-$(uname -r)"; then
    echo "安装内核头文件..."
    apt-get update
    apt-get install -y linux-headers-$(uname -r) build-essential
else
    echo -e "${GREEN}✓${NC} 内核头文件已安装"
fi

# 2. 编译驱动
echo -e "${BLUE}[2/5] 编译驱动...${NC}"
if [ -f "Makefile" ]; then
    make clean || true
    make
    echo -e "${GREEN}✓${NC} 编译成功"
elif [ -f "install.sh" ]; then
    echo "发现 install.sh，执行安装脚本..."
    chmod +x install.sh
    ./install.sh
    exit 0
else
    echo -e "${YELLOW}[WARNING] 未找到 Makefile 或 install.sh${NC}"
    echo "请查看驱动目录中的安装说明"
    ls -la "$DRIVER_DIR"
    exit 1
fi

# 3. 安装驱动模块
echo -e "${BLUE}[3/5] 安装驱动模块...${NC}"
KERNEL_VERSION=$(uname -r)
INSTALL_DIR="/lib/modules/${KERNEL_VERSION}/kernel/drivers/net/can"
mkdir -p "$INSTALL_DIR"

# 查找编译好的 .ko 文件
KO_FILE=$(find . -name "*.ko" | head -1)
if [ -z "$KO_FILE" ]; then
    echo -e "${RED}[ERROR] 未找到 .ko 文件${NC}"
    exit 1
fi

cp "$KO_FILE" "$INSTALL_DIR/"
KO_NAME=$(basename "$KO_FILE" .ko)
echo -e "${GREEN}✓${NC} 驱动模块已安装: $KO_NAME"

# 4. 加载驱动
echo -e "${BLUE}[4/5] 加载驱动...${NC}"
depmod -a
modprobe can
modprobe can_raw
modprobe can_dev

# 尝试加载新驱动
if modprobe "$KO_NAME" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} 驱动加载成功"
else
    echo -e "${YELLOW}[WARNING] modprobe 失败，尝试 insmod...${NC}"
    insmod "$INSTALL_DIR/$KO_FILE" || {
        echo -e "${RED}[ERROR] 驱动加载失败${NC}"
        echo "检查 dmesg 查看错误信息"
        exit 1
    }
fi

# 5. 创建udev规则（可选）
echo -e "${BLUE}[5/5] 配置设备权限...${NC}"
cat > /etc/udev/rules.d/99-zlgcanfd.rules << 'EOF'
# ZLG USB-CANFD devices
SUBSYSTEM=="usb", ATTR{idVendor}=="3068", ATTR{idProduct}=="0009", MODE="0666", GROUP="can"
SUBSYSTEM=="net", KERNEL=="can*", ACTION=="add", RUN+="/sbin/ip link set %k type can bitrate 1000000"
EOF

udevadm control --reload-rules
udevadm trigger

echo -e "${GREEN}✓${NC} udev规则已创建"

# 检查设备
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  安装完成！${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

sleep 2

# 检查是否创建了CAN接口
echo "CAN接口状态:"
ip link show | grep -E "can[0-9]" || echo "  (暂未发现CAN接口，请重新插拔设备)"

echo ""
echo "USB设备:"
lsusb | grep "3068:0009" || echo "  (未发现ZLG设备)"

echo ""
echo "加载的模块:"
lsmod | grep -E "can|zlg" || true

echo ""
echo -e "${GREEN}使用说明:${NC}"
echo "  1. 重新插拔ZLG设备，或重启系统"
echo "  2. 检查CAN接口: ip link show"
echo "  3. 启用CAN: sudo ip link set canX up type can bitrate 1000000"
echo "  4. 测试: candump canX"
echo ""
echo "如果安装后没有自动创建can接口，请运行:"
echo "  sudo ./scripts/s4 can auto"
