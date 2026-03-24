#!/bin/bash
# Blueberry S4 - CAN 设备管理器
# 自动检测、配置和管理所有 CAN 接口
# Usage: can_manager.sh [status|setup|auto|install-driver]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# CAN 配置
DEFAULT_BITRATE=500000
CAN_CONFIG_FILE="$PROJECT_DIR/config/can_devices.yaml"

# 打印带颜色的消息
print_info() { echo -e "${BLUE}[CAN]${NC} $1"; }
print_success() { echo -e "${GREEN}[CAN]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[CAN]${NC} $1"; }
print_error() { echo -e "${RED}[CAN]${NC} $1"; }

# 显示标题
show_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}           🔌 Blueberry S4 CAN 设备管理器               ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# 检查是否为 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "此操作需要 root 权限"
        print_info "请运行: sudo $0 $1"
        exit 1
    fi
}

# 获取 CAN 接口的驱动类型
get_can_driver() {
    local iface=$1
    if [ -L "/sys/class/net/$iface/device/driver" ]; then
        readlink -f "/sys/class/net/$iface/device/driver" 2>/dev/null | xargs basename 2>/dev/null
    else
        echo "virtual"
    fi
}

# 获取 USB CAN 设备的 USB ID
get_usb_id() {
    local iface=$1
    local driver=$(get_can_driver $iface)
    
    if [ "$driver" = "pcan" ]; then
        # PEAK 设备
        echo "0c72:000c"
    elif [ "$driver" = "gs_usb" ]; then
        # 通用 USB-CAN (如 CANable)
        cat "/sys/class/net/$iface/device/uevent" 2>/dev/null | grep "PRODUCT=" | cut -d'=' -f2
    else
        echo "builtin"
    fi
}

# 检测所有 CAN 设备
detect_can_devices() {
    print_info "扫描 CAN 设备..."
    
    declare -A CAN_DEVICES
    local count=0
    
    # 获取所有 CAN 接口
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E "^can" | sort -V); do
        if ip link show "$iface" &>/dev/null; then
            local state=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}')
            local driver=$(get_can_driver "$iface")
            local usb_id=$(get_usb_id "$iface")
            
            CAN_DEVICES[$iface]="state:$state;driver:$driver;usb_id:$usb_id"
            count=$((count + 1))
            
            # 显示状态
            local state_icon="${RED}●${NC}"
            [[ "$state" == *"UP"* ]] && state_icon="${GREEN}●${NC}"
            [[ "$state" == *"DOWN"* ]] && state_icon="${YELLOW}●${NC}"
            
            printf "  %s %-6s | %-10s | %-15s | %s\n" \
                "$state_icon" "$iface" "$state" "$driver" "$usb_id"
        fi
    done
    
    if [ $count -eq 0 ]; then
        print_warning "未找到任何 CAN 接口"
        return 1
    fi
    
    echo ""
    print_success "找到 $count 个 CAN 接口"
    return 0
}

# 检查 PEAK 驱动是否安装
check_peak_driver() {
    if lsmod | grep -q "^pcan"; then
        return 0
    fi
    if [ -f "/lib/modules/$(uname -r)/kernel/drivers/net/can/pcan.ko" ]; then
        return 0
    fi
    return 1
}

# 安装 PEAK 驱动
install_peak_driver() {
    check_root "install-driver"
    
    print_info "安装 PEAK USB-CAN 驱动..."
    
    local DRIVER_DIR="$PROJECT_DIR/drivers/peak-linux-driver-8.18.0"
    
    if [ ! -d "$DRIVER_DIR" ]; then
        print_error "驱动源码未找到: $DRIVER_DIR"
        print_info "请先下载驱动: wget https://www.peak-system.com/..."
        return 1
    fi
    
    cd "$DRIVER_DIR"
    
    # 检查依赖
    print_info "检查编译依赖..."
    if ! command -v make &>/dev/null; then
        print_info "安装 build-essential..."
        apt-get update -qq
        apt-get install -y -qq build-essential linux-headers-$(uname -r)
    fi
    
    # 清理并编译
    print_info "编译驱动 (netdev 模式)..."
    make clean >/dev/null 2>&1 || true
    make netdev -j$(nproc) 2>&1 | tail -20
    
    if [ ! -f "driver/pcan.ko" ]; then
        print_error "编译失败"
        return 1
    fi
    
    # 安装
    print_info "安装驱动模块..."
    local INSTALL_DIR="/lib/modules/$(uname -r)/kernel/drivers/net/can"
    mkdir -p "$INSTALL_DIR"
    cp driver/pcan.ko "$INSTALL_DIR/"
    chmod 644 "$INSTALL_DIR/pcan.ko"
    
    # 更新依赖
    depmod -a
    
    # 加载
    print_info "加载驱动..."
    modprobe can
    modprobe can_raw
    modprobe can_dev
    modprobe pcan
    
    sleep 2
    
    if lsmod | grep -q "^pcan"; then
        print_success "PEAK 驱动安装成功！"
        return 0
    else
        print_error "驱动加载失败"
        return 1
    fi
}

# 配置单个 CAN 接口
setup_can_interface() {
    local iface=$1
    local bitrate=${2:-$DEFAULT_BITRATE}
    
    print_info "配置 $iface @ ${bitrate}bps..."
    
    # 关闭接口
    ip link set "$iface" down 2>/dev/null || true
    
    # 设置比特率
    ip link set "$iface" type can bitrate "$bitrate"
    
    # 启用接口
    ip link set "$iface" up
    
    if ip link show "$iface" | grep -q "UP"; then
        print_success "$iface 已启用"
        return 0
    else
        print_error "$iface 启用失败"
        return 1
    fi
}

# 自动配置所有 CAN 设备
auto_setup() {
    check_root "auto"
    show_header
    
    print_info "自动配置 CAN 设备..."
    echo ""
    
    # 1. 检查并安装 PEAK 驱动
    if lsusb | grep -q "0c72:000c"; then
        if ! check_peak_driver; then
            print_warning "检测到 PEAK USB-CAN 但未安装驱动"
            install_peak_driver || true
        fi
    fi
    
    # 2. 等待设备初始化
    print_info "等待设备初始化..."
    sleep 3
    
    # 3. 检测并配置所有 CAN 接口
    echo ""
    print_info "配置 CAN 接口..."
    echo ""
    
    local success_count=0
    
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E "^can" | sort -V); do
        if ip link show "$iface" &>/dev/null; then
            local driver=$(get_can_driver "$iface")
            local bitrate=$DEFAULT_BITRATE
            
            # 根据驱动类型设置不同比特率
            case "$driver" in
                mttcan)
                    # Jetson 内置 CAN，通常用于高速设备
                    bitrate=500000
                    ;;
                pcan)
                    # PEAK USB-CAN
                    bitrate=500000
                    ;;
                gs_usb)
                    # 通用 USB-CAN
                    bitrate=500000
                    ;;
            esac
            
            if setup_can_interface "$iface" "$bitrate"; then
                success_count=$((success_count + 1))
            fi
        fi
    done
    
    echo ""
    if [ $success_count -gt 0 ]; then
        print_success "成功配置 $success_count 个 CAN 接口"
    else
        print_warning "没有配置任何 CAN 接口"
    fi
    
    # 4. 显示最终状态
    echo ""
    print_info "最终状态:"
    detect_can_devices
}

# 显示状态
show_status() {
    show_header
    
    print_info "系统 CAN 状态"
    echo ""
    
    # 显示内核模块
    print_info "已加载的 CAN 模块:"
    lsmod | grep -E "can|pcan|peak" | while read line; do
        echo "  $line"
    done
    echo ""
    
    # 显示 USB 设备
    print_info "USB CAN 设备:"
    if lsusb | grep -iE "peak|can" | grep -v "canberra" | grep -v "clutter" | grep -v "libcan" | while read line; do
        echo "  $line"
    done; then
        :
    else
        echo "  未检测到 USB CAN 设备"
    fi
    echo ""
    
    # 显示网络接口
    print_info "CAN 网络接口:"
    detect_can_devices || true
}

# 主函数
main() {
    case "${1:-status}" in
        status)
            show_status
            ;;
        setup)
            check_root "setup"
            shift
            if [ -z "$1" ]; then
                print_error "请指定接口名"
                print_info "用法: $0 setup <can0|can1|can2> [bitrate]"
                exit 1
            fi
            setup_can_interface "$1" "${2:-$DEFAULT_BITRATE}"
            ;;
        auto)
            auto_setup
            ;;
        install-driver)
            show_header
            install_peak_driver
            ;;
        help|-h|--help)
            echo "Blueberry S4 CAN 设备管理器"
            echo ""
            echo "用法: $0 [command]"
            echo ""
            echo "命令:"
            echo "  status          显示 CAN 设备状态 (默认)"
            echo "  setup <iface>   配置指定 CAN 接口"
            echo "  auto            自动检测并配置所有 CAN 设备"
            echo "  install-driver  安装 PEAK USB-CAN 驱动"
            echo "  help            显示帮助"
            echo ""
            echo "示例:"
            echo "  $0 status                    # 查看状态"
            echo "  $0 auto                      # 自动配置"
            echo "  sudo $0 setup can2 500000    # 配置 can2 @ 500K"
            echo "  sudo $0 install-driver       # 安装驱动"
            ;;
        *)
            print_error "未知命令: $1"
            print_info "运行 '$0 help' 查看用法"
            exit 1
            ;;
    esac
}

main "$@"
