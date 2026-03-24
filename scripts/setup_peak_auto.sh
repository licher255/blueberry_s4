#!/bin/bash
# Blueberry S4 - PEAK USB-CAN 自动配置脚本
# 添加到 /etc/rc.local 或 systemd 服务

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[PEAK Setup]${NC} $1"
}

# 等待 USB 设备初始化完成
sleep 3

# 1. 检查 PEAK 设备
log "检查 PEAK USB-CAN 设备..."
if ! lsusb | grep -q "0c72:000c"; then
    log "${RED}未找到 PEAK USB-CAN 设备${NC}"
    exit 1
fi
log "${GREEN}✓ PEAK 设备已连接${NC}"

# 2. 方案 A: 使用 SocketCAN 模式 (推荐)
# 卸载 chardev 驱动，加载 socketcan 驱动
log "切换到 SocketCAN 模式..."

# 检查当前驱动
if lsmod | grep -q "^pcan"; then
    log "卸载 pcan 驱动..."
    rmmod pcan 2>/dev/null || true
fi

# 加载 SocketCAN 驱动
modprobe can
modprobe can_raw
modprobe can_dev
modprobe peak_usb 2>/dev/null || {
    log "${YELLOW}peak_usb 驱动加载失败，可能未安装${NC}"
    log "尝试重新加载 pcan 驱动..."
    modprobe pcan
}

# 等待设备创建
sleep 2

# 3. 查找并配置 CAN 接口
log "查找 CAN 接口..."
CAN_IFACE=""

for iface in can0 can1 can2 can3; do
    if ip link show $iface &>/dev/null; then
        # 检查是否是 USB 设备 (不是 mttcan)
        DRIVER=$(readlink -f /sys/class/net/$iface/device/driver 2>/dev/null | xargs basename 2>/dev/null || echo "")
        if [ "$DRIVER" != "mttcan" ] && [ -n "$DRIVER" ]; then
            CAN_IFACE=$iface
            log "找到 USB-CAN 接口: $iface (驱动: $DRIVER)"
            break
        fi
    fi
done

# 4. 如果没有找到 USB-CAN，使用 can0 (可能是内置)
if [ -z "$CAN_IFACE" ]; then
    if ip link show can0 &>/dev/null; then
        CAN_IFACE="can0"
        log "使用内置 CAN 接口: can0"
    fi
fi

# 5. 配置 CAN 接口
if [ -n "$CAN_IFACE" ]; then
    log "配置 $CAN_IFACE @ 500000bps..."
    
    ip link set $CAN_IFACE down 2>/dev/null || true
    ip link set $CAN_IFACE type can bitrate 500000
    ip link set $CAN_IFACE up
    
    if ip link show $CAN_IFACE | grep -q "UP"; then
        log "${GREEN}✓ $CAN_IFACE 已启用${NC}"
        
        # 显示状态
        echo "   接口状态:"
        ip -br addr show $CAN_IFACE
    else
        log "${RED}✗ $CAN_IFACE 启用失败${NC}"
    fi
else
    log "${RED}✗ 未找到可用的 CAN 接口${NC}"
    exit 1
fi

# 6. 如果是 chardev 模式，尝试打开设备使灯闪烁
if [ -e /dev/pcanusb32 ]; then
    log "检测到 chardev 模式设备"
    log "提示: 灯不闪是因为没有应用程序打开设备"
    log "运行 CAN 节点后灯应该会闪烁"
fi

log "${GREEN}✓ PEAK USB-CAN 配置完成${NC}"
exit 0
