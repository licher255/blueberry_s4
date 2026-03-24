#!/bin/bash
# Blueberry S4 - 安装 CAN 自动配置服务
# 使 CAN 设备在开机时自动配置

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  安装 Blueberry S4 CAN 自动配置服务${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""

# 1. 复制服务文件
echo -e "${YELLOW}[1/4] 安装 systemd 服务...${NC}"
cp "$PROJECT_DIR/install/can_service/blueberry-can.service" /etc/systemd/system/

# 2. 更新服务文件中的路径（如果项目路径不同）
if [ "$PROJECT_DIR" != "/home/hkclr/Blueberry_s4" ]; then
    echo -e "${YELLOW}  更新服务文件路径...${NC}"
    sed -i "s|/home/hkclr/Blueberry_s4|$PROJECT_DIR|g" /etc/systemd/system/blueberry-can.service
fi

echo -e "${GREEN}✓ 服务文件已安装${NC}"

# 3. 创建 udev 规则（USB CAN 设备热插拔）
echo ""
echo -e "${YELLOW}[2/4] 配置 udev 规则...${NC}"

cat > /etc/udev/rules.d/99-blueberry-can.rules << 'EOF'
# Blueberry S4 CAN 设备规则

# PEAK USB-CAN 设备
SUBSYSTEM=="usb", ATTR{idVendor}=="0c72", ATTR{idProduct}=="000c", TAG+="systemd", ENV{SYSTEMD_WANTS}="blueberry-can.service"

# 通用 USB-CAN (gs_usb, CANable等)
SUBSYSTEM=="usb", ATTR{idVendor}=="1d50", ATTR{idProduct}=="606f", TAG+="systemd", ENV{SYSTEMD_WANTS}="blueberry-can.service"
SUBSYSTEM=="usb", ATTR{idVendor}=="1209", ATTR{idProduct}=="0001", TAG+="systemd", ENV{SYSTEMD_WANTS}="blueberry-can.service"

# CAN 网络设备自动配置
SUBSYSTEM=="net", KERNEL=="can*", ACTION=="add", RUN+="/bin/bash /home/hkclr/Blueberry_s4/scripts/can_manager.sh setup %k"
EOF

# 更新路径
if [ "$PROJECT_DIR" != "/home/hkclr/Blueberry_s4" ]; then
    sed -i "s|/home/hkclr/Blueberry_s4|$PROJECT_DIR|g" /etc/udev/rules.d/99-blueberry-can.rules
fi

echo -e "${GREEN}✓ udev 规则已配置${NC}"

# 4. 重载 systemd
echo ""
echo -e "${YELLOW}[3/4] 重载 systemd...${NC}"
systemctl daemon-reload
udevadm control --reload-rules
udevadm trigger

echo -e "${GREEN}✓ systemd 已重载${NC}"

# 5. 启用服务
echo ""
echo -e "${YELLOW}[4/4] 启用开机启动...${NC}"
systemctl enable blueberry-can.service

echo -e "${GREEN}✓ 服务已启用${NC}"

# 6. 立即运行一次测试
echo ""
echo -e "${YELLOW}立即测试 CAN 配置...${NC}"
bash "$PROJECT_DIR/scripts/can_manager.sh" auto || true

# 7. 显示状态
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ CAN 自动配置服务安装完成！${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo ""
echo "管理命令:"
echo "  查看状态:  sudo systemctl status blueberry-can"
echo "  手动运行:  sudo systemctl start blueberry-can"
echo "  查看日志:  sudo journalctl -u blueberry-can -f"
echo ""
echo "CAN 管理命令:"
echo "  查看状态:  bash scripts/can_manager.sh status"
echo "  自动配置:  sudo bash scripts/can_manager.sh auto"
echo "  安装驱动:  sudo bash scripts/can_manager.sh install-driver"
echo ""
