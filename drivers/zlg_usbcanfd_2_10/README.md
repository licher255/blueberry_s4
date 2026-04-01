# ZLG USB-CANFD 驱动安装指南

## 快速安装

```bash
cd drivers/zlg_usbcanfd_2_10
sudo ./install.sh
```

## 支持的设备

- USBCANFD-100U-mini (VID:PID = 3068:0009)
- USBCANFD-200U (VID:PID = 04CC:1240)

## 手动安装步骤

### 1. 安装依赖

```bash
sudo apt-get update
sudo apt-get install can-utils linux-headers-$(uname -r)
```

### 2. 编译驱动

```bash
cd drivers/zlg_usbcanfd_2_10
make
```

### 3. 安装并加载驱动

```bash
sudo cp usbcanfd.ko /lib/modules/$(uname -r)/kernel/drivers/net/can/
sudo depmod -a
sudo modprobe usbcanfd
```

### 4. 配置自动加载

```bash
echo "usbcanfd" | sudo tee /etc/modules-load.d/zlg-usbcanfd.conf
```

## 配置 CAN 接口

### CANFD 模式 (推荐)

```bash
# 设置 CANFD: 仲裁段 1M, 数据段 2M
sudo ip link set can0 type can fd on bitrate 1000000 dbitrate 2000000
sudo ip link set can0 up
```

### 普通 CAN 模式

```bash
sudo ip link set can0 type can bitrate 1000000
sudo ip link set can0 up
```

## 检查状态

```bash
# 查看 USB 设备
lsusb | grep ZLG

# 查看驱动
lsmod | grep usbcanfd

# 查看接口
ip -details link show can0
```

## 故障排除

### 驱动无法加载

1. 检查内核版本是否匹配
2. 确认内核头文件已安装
3. 查看 dmesg 日志: `sudo dmesg | tail -50`

### 接口未创建

1. 重新插拔 USB 设备
2. 手动加载驱动: `sudo modprobe usbcanfd`
3. 检查权限: `sudo chmod 666 /dev/bus/usb/XXX/YYY`

### 使用 s4 工具

项目主目录下的 `s4` 脚本已集成 ZLG 驱动支持:

```bash
sudo ./s4 init    # 自动检测并配置 ZLG CANFD @ 1Mbps
./s4 dev          # 启动开发环境
```

## 驱动版本

- 版本: 2.10
- 内核: 5.15.x (Jetson)
- 许可证: GPL
