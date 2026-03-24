#!/bin/bash
# Blueberry S4 - CAN 接口设置脚本

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 参数
CAN_IFACE="${1:-can0}"
BITRATE="${2:-500000}"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}              🫐 Blueberry S4 CAN 设置                  ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# 检查是否为 root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}⚠️  需要 root 权限来配置 CAN 接口${NC}"
    echo "   运行: sudo bash scripts/setup_can.sh"
    exit 1
fi

echo -e "${YELLOW}🔧 配置 CAN 接口: $CAN_IFACE @ ${BITRATE}bps${NC}"
echo ""

# 检查 CAN 接口是否存在
if ! ip link show $CAN_IFACE &> /dev/null; then
    echo -e "${YELLOW}⚠️  接口 $CAN_IFACE 不存在，尝试加载 CAN 驱动...${NC}"
    
    # 尝试加载 SocketCAN 驱动
    modprobe can
    modprobe can_raw
    modprobe can_dev
    modprobe peak_usb 2>/dev/null || true  # PEAK USB-CAN 适配器
    modprobe usb_8dev 2>/dev/null || true  # USB2CAN 适配器
    modprobe slcan 2>/dev/null || true     # SLCAN 适配器
    
    sleep 1
    
    if ! ip link show $CAN_IFACE &> /dev/null; then
        echo -e "${RED}❌ 接口 $CAN_IFACE 仍不存在${NC}"
        echo -e "${YELLOW}   可能的 USB-CAN 设备列表:${NC}"
        lsusb | grep -iE "can|peak|kvaser|8dev" || echo "   未找到 USB-CAN 设备"
        echo ""
        echo -e "${YELLOW}   所有 CAN 接口:${NC}"
        ip link show type can 2>/dev/null || echo "   无 CAN 接口"
        exit 1
    fi
fi

# 关闭接口（如果已开启）
echo "   关闭接口..."
ip link set $CAN_IFACE down 2>/dev/null || true

# 设置比特率
echo "   设置比特率 ${BITRATE}..."
ip link set $CAN_IFACE type can bitrate $BITRATE

# 开启接口
echo "   开启接口..."
ip link set $CAN_IFACE up

# 验证
if ip link show $CAN_IFACE | grep -q "UP"; then
    echo ""
    echo -e "${GREEN}✅ CAN 接口 $CAN_IFACE 已启用${NC}"
    ip -br addr show $CAN_IFACE
else
    echo -e "${RED}❌ 启用失败${NC}"
    exit 1
fi

# 显示统计
echo ""
echo -e "${BLUE}📊 CAN 统计:${NC}"
ip -s link show $CAN_IFACE | grep -E "(RX|TX|errors|dropped)"

echo ""
echo -e "${GREEN}🎉 完成！现在可以启动机器人:${NC}"
echo "   bash scripts/start_robot.sh"
echo ""
