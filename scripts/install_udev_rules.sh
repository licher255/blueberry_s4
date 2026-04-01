#!/bin/bash
# Blueberry S4 - 安装 CAN 设备持久化命名规则
# 方案1: 创建符号链接别名，保持原 canX 名称不变

set -e

echo "🔧 安装 CAN 设备 udev 规则..."
echo ""

# 检测当前设备状态
echo "📋 当前 CAN 设备状态:"
echo "  can2 -> PEAK (pcan) - AGV 连接于此"
echo "  can3 -> ZLG (usbcanfd) - CANFD 设备"
echo ""

# 先删除可能存在的旧规则
sudo rm -f /etc/udev/rules.d/99-s4-can.rules

# 创建新的规则文件
sudo tee /etc/udev/rules.d/99-s4-can.rules > /dev/null << 'UDEOF'
# Blueberry S4 - CAN 设备持久化命名
# 创建符号链接别名，保持原 canX 名称不变

# ZLG USBCANFD-100U-mini -> can_fd (基于序列号绑定，最可靠)
# 序列号: D928DFEFA0D00E141990
SUBSYSTEM=="net", ACTION=="add", ATTRS{idVendor}=="3068", ATTRS{idProduct}=="0009", ATTRS{serial}=="D928DFEFA0D00E141990", SYMLINK+="can_fd"

# PEAK PCAN-USB -> can_agv (基于USB端口路径绑定)
# 当前插在 Port 4.3，路径: 1-4.3:1.0
SUBSYSTEM=="net", ACTION=="add", KERNELS=="1-4.3:1.0", SYMLINK+="can_agv"
UDEOF

# 设置权限
sudo chmod 644 /etc/udev/rules.d/99-s4-can.rules

# 重新加载规则
sudo udevadm control --reload-rules

echo "✅ udev 规则已安装"
echo ""
echo "规则内容:"
cat /etc/udev/rules.d/99-s4-can.rules
echo ""
echo "⚠️  重要提示:"
echo "  1. PEAK (can_agv) 基于 USB 端口绑定 (Port 4.3)"
echo "  2. 如果更换 USB 端口，需要重新运行此脚本"
echo "  3. ZLG (can_fd) 基于序列号，不受端口影响"
echo ""
echo "🔄 生效方式（二选一）:"
echo "  A. 重新插拔两个 CAN 设备"
echo "  B. 重启系统"
echo ""
echo "🔍 验证方法:"
echo "  ls -la /sys/class/net/can_agv /sys/class/net/can_fd"
echo ""
echo "预期结果:"
echo "  can_agv -> can2  (PEAK PCAN-USB)"
echo "  can_fd  -> can3  (ZLG USBCANFD)"
