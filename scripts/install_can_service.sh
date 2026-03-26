#!/bin/bash
# 安装 CAN 开机服务

set -e
[ "$EUID" -ne 0 ] && { echo "需要 root: sudo $0"; exit 1; }

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="blueberry-can.service"

echo "🔌 安装 CAN 开机服务..."

# 安装依赖
python3 -c "import yaml" 2>/dev/null || apt-get install -y python3-yaml 2>/dev/null || pip3 install pyyaml

# udev 规则
cat > /etc/udev/rules.d/99-blueberry-can.rules << 'EOF'
SUBSYSTEM=="net", ACTION=="add", ATTRS{idVendor}=="3068", ATTRS{idProduct}=="0009", NAME="can3"
SUBSYSTEM=="net", ACTION=="add", ATTRS{idVendor}=="0c72", ATTRS{idProduct}=="000c", NAME="can2"
EOF
udevadm control --reload-rules

# 模块加载顺序
for mod in can can_raw can_dev usbcanfd pcan; do
    grep -q "^$mod$" /etc/modules 2>/dev/null || echo "$mod" >> /etc/modules
done

# modprobe 配置
cat > /etc/modprobe.d/blueberry-can.conf << 'EOF'
# ZLG 先于 PEAK 加载
softdep pcan pre: usbcanfd
EOF

# systemd 服务
cat > /etc/systemd/system/$SERVICE << 'EOF'
[Unit]
Description=Blueberry S4 CAN
After=systemd-modules-load.service
Before=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/python3 /home/hkclr/Blueberry_s4/scripts/can_initializer.py
ExecStop=/bin/sh -c 'ip link set can2 down 2>/dev/null; ip link set can3 down 2>/dev/null'
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable $SERVICE

# 立即测试
echo "🧪 测试初始化..."
python3 "$PROJECT_DIR/scripts/can_initializer.py"

echo ""
echo "✅ 安装完成"
echo "管理: sudo systemctl status/start/stop $SERVICE"
