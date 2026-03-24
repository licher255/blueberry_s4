#!/bin/bash
# 安装 PEAK USB-CAN 驱动 (PCAN-USB)
# 适用于 Jetson (Ubuntu 22.04, Kernel 5.15)

set -e

echo "========================================"
echo "PEAK USB-CAN 驱动安装脚本"
echo "========================================"
echo ""

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then 
    echo "请使用 sudo 运行此脚本"
    exit 1
fi

# 安装依赖
echo "[1/5] 安装依赖..."
apt-get update
apt-get install -y linux-headers-$(uname -r) git build-essential dkms

# 创建工作目录
WORK_DIR="/tmp/peak_driver_build"
mkdir -p $WORK_DIR
cd $WORK_DIR

# 下载 peak-linux-driver
echo ""
echo "[2/5] 下载 PEAK Linux 驱动..."
if [ -d "peak-linux-driver" ]; then
    rm -rf peak-linux-driver
fi
git clone https://github.com/linux-can/peak_usb.git peak-linux-driver 2>/dev/null || \
git clone https://github.com/linux-can/peak_linux_devel.git peak-linux-driver 2>/dev/null || \
(echo "从 GitHub 下载失败，尝试备用的方式..." && \
 wget -q https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-8.18.0.tar.gz && \
 tar -xzf peak-linux-driver-8.18.0.tar.gz && \
 mv peak-linux-driver-8.18.0 peak-linux-driver)

cd peak-linux-driver

# 编译并安装驱动
echo ""
echo "[3/5] 编译驱动..."
make clean 2>/dev/null || true
make -j$(nproc)

echo ""
echo "[4/5] 安装驱动..."
make install

# 加载驱动
echo ""
echo "[5/5] 加载驱动..."
modprobe peak_usb || insmod ./driver/peak_usb.ko 2>/dev/null || true

# 验证安装
echo ""
echo "========================================"
echo "验证安装..."
echo "========================================"

sleep 2

# 检查驱动是否加载
if lsmod | grep -q peak_usb; then
    echo "✅ peak_usb 驱动已加载"
else
    echo "⚠️ 驱动未自动加载，尝试手动加载..."
    modprobe peak_usb 2>/dev/null || echo "手动加载失败"
fi

# 检查新的 CAN 接口
echo ""
echo "当前 CAN 接口:"
ip link show | grep can

# 检查设备节点
if ls /sys/class/net/can* 1>/dev/null 2>&1; then
    echo ""
    echo "✅ CAN 接口已创建!"
    for iface in $(ls /sys/class/net/ | grep can); do
        echo "  - $iface"
    done
else
    echo ""
    echo "⚠️ 未检测到新的 CAN 接口"
    echo "请重新插拔 USB-CAN 适配器后再试"
fi

echo ""
echo "========================================"
echo "安装完成!"
echo "========================================"
echo ""
echo "使用方法:"
echo "  1. 如果 CAN 接口已创建:"
echo "     sudo ip link set canX up type can bitrate 500000"
echo "     candump canX"
echo ""
echo "  2. 如果没有新接口，请重新插拔 USB-CAN 设备"
echo ""
echo "  3. 测试 AGV:"
echo "     ros2 launch bringup robot.launch.py"
echo ""

# 清理
rm -rf $WORK_DIR
