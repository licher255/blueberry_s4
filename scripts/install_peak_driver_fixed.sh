#!/bin/bash
# Blueberry S4 - PEAK USB-CAN 驱动编译安装脚本 (修复版)
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

cd /tmp/peak-linux-driver-8.18.0

echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PEAK USB-CAN 驱动重新编译 (SocketCAN 模式)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 1. 清理
echo -e "${YELLOW}[1/5] 清理...${NC}"
make clean

# 2. 编译 netdev 版本
echo ""
echo -e "${YELLOW}[2/5] 编译 netdev 版本...${NC}"
make netdev -j$(nproc) 2>&1 | tail -30

# 3. 检查编译结果
echo ""
echo -e "${YELLOW}[3/5] 检查编译结果...${NC}"
if [ -f "driver/pcan.ko" ]; then
    echo -e "${GREEN}✓ pcan.ko 编译成功${NC}"
    # 检查是否包含 netdev 符号
    if nm driver/pcan.ko 2>/dev/null | grep -q "register_netdev"; then
        echo -e "${GREEN}✓ 确认是 netdev 版本${NC}"
    fi
else
    echo -e "${RED}✗ 编译失败${NC}"
    exit 1
fi

# 4. 手动安装内核模块
echo ""
echo -e "${YELLOW}[4/5] 手动安装内核模块...${NC}"

KERNEL_VER=$(uname -r)
INSTALL_DIR="/lib/modules/${KERNEL_VER}/kernel/drivers/net/can"

# 创建目录
mkdir -p ${INSTALL_DIR}

# 复制模块
cp driver/pcan.ko ${INSTALL_DIR}/

# 设置权限
chmod 644 ${INSTALL_DIR}/pcan.ko

echo -e "${GREEN}✓ 模块安装到 ${INSTALL_DIR}/pcan.ko${NC}"

# 5. 更新模块依赖
echo ""
echo -e "${YELLOW}[5/5] 更新模块依赖...${NC}"
depmod -a

# 6. 加载模块
echo ""
echo -e "${YELLOW}加载驱动...${NC}"

# 先卸载旧模块
rmmod pcan 2>/dev/null || true

# 加载 CAN 基础模块
modprobe can
modprobe can_raw
modprobe can_dev

# 加载 pcan (netdev 版本)
modprobe pcan

# 检查是否加载成功
sleep 2
if lsmod | grep -q "^pcan"; then
    echo -e "${GREEN}✓ pcan 驱动加载成功！${NC}"
    
    # 查找网络接口
    echo ""
    echo -e "${YELLOW}查找 CAN 网络接口...${NC}"
    
    NEW_CAN=""
    for iface in can0 can1 can2 can3 can4 can5; do
        if ip link show $iface &>/dev/null; then
            DRIVER=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null)
            if [ "$DRIVER" = "pcan" ]; then
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
        echo -e "${YELLOW}⚠ 未找到 PEAK USB-CAN 接口${NC}"
        echo "所有 CAN 接口:"
        ip link show type can 2>/dev/null || echo "无"
    fi
else
    echo -e "${RED}✗ 驱动加载失败${NC}"
    echo "查看错误: dmesg | tail -20"
    exit 1
fi

echo ""
