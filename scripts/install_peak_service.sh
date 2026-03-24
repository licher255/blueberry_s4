#!/bin/bash
# Blueberry S4 - 安装 PEAK CAN 自动配置服务

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}安装 PEAK USB-CAN 自动配置服务${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}请使用 sudo 运行${NC}"
    exit 1
fi

# 1. 创建服务文件
cat > /etc/systemd/system/peak-can-setup.service << 'EOF'
[Unit]
Description=PEAK USB-CAN Auto Configuration
After=systemd-udev-settle.service
Wants=systemd-udev-settle.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/peak-can-setup.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# 2. 复制脚本
cp scripts/setup_peak_auto.sh /usr/local/bin/peak-can-setup.sh
chmod +x /usr/local/bin/peak-can-setup.sh

# 3. 创建 udev 规则（确保设备权限正确）
cat > /etc/udev/rules.d/99-peak-can.rules << 'EOF'
# PEAK USB-CAN 设备权限
SUBSYSTEM=="usb", ATTR{idVendor}=="0c72", ATTR{idProduct}=="000c", MODE="0666", GROUP="dialout"
SUBSYSTEM=="net", KERNEL=="can*", ACTION=="add", RUN+="/sbin/ip link set %k type can bitrate 500000", RUN+="/sbin/ip link set %k up"
EOF

# 4. 重新加载并启用服务
systemctl daemon-reload
systemctl enable peak-can-setup.service

# 5. 重新加载 udev
udevadm control --reload-rules
udevadm trigger

echo -e "${GREEN}✓ 服务安装完成${NC}"
echo ""
echo "命令:"
echo "  手动运行: sudo systemctl start peak-can-setup"
echo "  查看状态: sudo systemctl status peak-can-setup"
echo "  开机启用: sudo systemctl enable peak-can-setup (已启用)"
echo ""
echo -e "${YELLOW}提示: 重启后 CAN 接口将自动配置${NC}"
