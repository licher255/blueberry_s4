#!/bin/bash
# ZLG USB-CANFD 驱动安装脚本

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[ZLG]${NC} $1"; }
ok() { echo -e "${GREEN}[ZLG]${NC} ✓ $1"; }
warn() { echo -e "${YELLOW}[ZLG]${NC} ⚠ $1"; }
err() { echo -e "${RED}[ZLG]${NC} ✗ $1"; }

DRIVER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_root() {
    if [ "$EUID" -ne 0 ]; then
        err "需要 root 权限运行此脚本"
        echo "  请运行: sudo $0"
        exit 1
    fi
}

# 检查内核头文件
check_headers() {
    info "检查内核头文件..."
    if [ ! -d "/lib/modules/$(uname -r)/build" ]; then
        warn "内核头文件未安装"
        info "正在安装..."
        apt-get update -qq
        apt-get install -y -qq linux-headers-$(uname -r) || {
            err "内核头文件安装失败"
            exit 1
        }
    fi
    ok "内核头文件已就绪"
}

# 编译驱动
build_driver() {
    info "编译 ZLG USB-CANFD 驱动..."
    cd "$DRIVER_DIR"
    
    make clean 2>/dev/null || true
    make module 2>&1 | tail -20
    
    if [ ! -f "usbcanfd.ko" ]; then
        err "编译失败"
        exit 1
    fi
    
    ok "编译成功"
}

# 安装驱动
install_driver() {
    info "安装驱动..."
    
    local DEST_DIR="/lib/modules/$(uname -r)/kernel/drivers/net/can"
    mkdir -p "$DEST_DIR"
    cp "$DRIVER_DIR/usbcanfd.ko" "$DEST_DIR/"
    chmod 644 "$DEST_DIR/usbcanfd.ko"
    
    # 更新模块依赖
    depmod -a
    
    ok "驱动已安装到 $DEST_DIR"
}

# 配置自动加载
setup_autoload() {
    info "配置自动加载..."
    
    cat > /etc/modules-load.d/zlg-usbcanfd.conf << 'EOF'
# ZLG USB-CANFD driver
usbcanfd
EOF
    
    ok "自动加载配置已创建"
}

# 加载驱动
load_driver() {
    info "加载驱动..."
    
    modprobe can-dev 2>/dev/null || true
    modprobe usbcanfd 2>/dev/null || {
        insmod "$DRIVER_DIR/usbcanfd.ko" 2>/dev/null || true
    }
    
    sleep 2
    
    if lsmod | grep -q "^usbcanfd"; then
        ok "驱动已加载"
    else
        warn "驱动加载失败，可能需要重新插拔设备"
    fi
}

# 配置 CAN 接口
setup_can_interfaces() {
    info "配置 CAN 接口..."
    
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E "^can" | sort -V); do
        local driver=$(readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
        
        if [ "$driver" = "usbcanfd" ]; then
            info "配置 $iface (ZLG CANFD @ 1Mbps)..."
            ip link set "$iface" down 2>/dev/null || true
            # CANFD 模式: 仲裁段 1M, 数据段 2M
            ip link set "$iface" type can fd on bitrate 1000000 dbitrate 2000000 2>/dev/null || {
                # 如果 fd 模式失败，使用普通 CAN 模式
                ip link set "$iface" type can bitrate 1000000 2>/dev/null || true
            }
            ip link set "$iface" up 2>/dev/null && ok "$iface 已启动" || warn "$iface 启动失败"
        fi
    done
}

# 显示状态
show_status() {
    echo ""
    info "当前状态:"
    echo ""
    
    # 检查 USB 设备
    echo "USB 设备:"
    lsusb | grep -iE "zlg|04cc|3068" || echo "  未检测到 ZLG 设备"
    echo ""
    
    # 检查驱动
    echo "驱动状态:"
    lsmod | grep "^usbcanfd" && echo "  usbcanfd 已加载" || echo "  usbcanfd 未加载"
    echo ""
    
    # 检查接口
    echo "CAN 接口:"
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E "^can" | sort -V); do
        local driver=$(readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null || echo "unknown")
        local state=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}')
        echo "  $iface: $state ($driver)"
    done
}

# 主函数
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}        ZLG USB-CANFD 驱动安装工具 (v2.10)             ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    check_root
    check_headers
    build_driver
    install_driver
    setup_autoload
    load_driver
    setup_can_interfaces
    
    echo ""
    show_status
    
    echo ""
    ok "安装完成！"
    echo ""
    echo "提示:"
    echo "  - 驱动已安装到系统目录"
    echo "  - 已配置开机自动加载"
    echo "  - 重新插拔设备后运行: sudo ./install.sh reload"
    echo ""
}

# 处理参数
case "${1:-install}" in
    install)
        main
        ;;
    reload)
        check_root
        load_driver
        setup_can_interfaces
        show_status
        ;;
    status)
        show_status
        ;;
    uninstall)
        check_root
        info "卸载驱动..."
        rmmod usbcanfd 2>/dev/null || true
        rm -f /lib/modules/*/kernel/drivers/net/can/usbcanfd.ko
        rm -f /etc/modules-load.d/zlg-usbcanfd.conf
        depmod -a
        ok "驱动已卸载"
        ;;
    *)
        echo "用法: $0 [install|reload|status|uninstall]"
        exit 1
        ;;
esac
