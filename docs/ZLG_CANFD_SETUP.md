# ZLG USB-CANFD-100U-mini 安装指南

## ✅ 安装完成确认

驱动已成功安装并创建了 `can3` 接口！

## 📋 快速使用

### 1. 配置CAN-FD (每次重启后需要)
```bash
# 使用快捷脚本
sudo ./scripts/setup_zlg_canfd.sh can3

# 或手动配置
sudo ip link set can3 up type can fd on bitrate 1000000 dbitrate 5000000
```

### 2. 测试通信
```bash
# 监听所有消息
candump can3

# 发送测试消息
cansend can3 123#11.22.33.44.55.66.77.88

# 发送CAN-FD消息 (12字节)
cansend can3 123##2.00.11.22.33.44.55.66.77.88.AA.BB
```

### 3. 启动WHJ驱动
```bash
cd ~/Blueberry_s4
source install/setup.bash
ros2 launch whj_can_control whj_can_control.launch.py can_interface:=can3
```

### 4. 使用S4命令（一站式）
```bash
# 自动配置所有CAN设备（包括ZLG）
sudo ./scripts/s4 can auto

# 检查状态
./scripts/s4 check

# 测试WHJ
./scripts/test_whj.sh can3
```

## 🔧 技术细节

### 驱动信息
- **驱动路径**: `drivers/usbcanfd200_400u_2.10/`
- **内核模块**: `usbcanfd.ko`
- **设备ID**: `3068:0009`
- **创建接口**: `can3`, `can4` (双通道)

### CAN-FD 配置参数
| 参数 | 值 | 说明 |
|-----|-----|------|
| 仲裁率 | 1 Mbps | CAN标准帧速率 |
| 数据率 | 5 Mbps | CAN-FD数据段速率 |
| 采样点 | 75% | 仲裁段采样点 |
| 数据采样点 | 80% | 数据段采样点 |

### 可用命令
```bash
# 查看接口详情
ip -details link show can3

# 查看CAN统计
ifconfig can3

# 更改比特率
sudo ip link set can3 down
sudo ip link set can3 up type can fd on bitrate 500000 dbitrate 2000000

# 卸载驱动
sudo rmmod usbcanfd

# 重新加载驱动
sudo modprobe usbcanfd
```

## 📂 文件结构
```
drivers/
└── usbcanfd200_400u_2.10/
    ├── usbcanfd.c          # 驱动源码
    ├── usbcanfd.h          # 头文件
    ├── usbcanfd.ko         # 编译后的模块
    ├── Makefile
    └── readme.txt          # 官方文档

scripts/
├── install_zlg_driver.sh   # 驱动安装脚本
├── setup_zlg_canfd.sh      # CAN-FD配置脚本
└── test_whj.sh             # WHJ测试脚本
```

## 🔍 故障排除

### 问题1: 没有can3接口
```bash
# 检查驱动是否加载
lsmod | grep usbcanfd

# 检查USB设备
lsusb | grep 3068

# 重新插拔设备或重新加载驱动
sudo rmmod usbcanfd
sudo modprobe usbcanfd
```

### 问题2: CAN接口无法启用
```bash
# 查看错误信息
sudo dmesg | tail -20

# 检查比特率参数是否支持
ip link set can3 up type can help
```

### 问题3: 接收不到数据
```bash
# 检查接口状态
ip -details link show can3

# 检查统计信息
ifconfig can3

# 增加接收缓冲区
sudo sysctl -w net.core.rmem_max=26214400
sudo sysctl -w net.core.rmem_default=26214400
```

## 📝 注意事项

1. **WHJ协议**: 当前的 `whj_can_control_node.cpp` 使用的是占位符协议，需要根据实际的WHJ协议文档更新CAN ID和数据格式。

2. **自动启动**: 如需开机自动加载驱动，添加到 `/etc/modules`：
   ```bash
   echo 'usbcanfd' | sudo tee -a /etc/modules
   ```

3. **udev权限**: 驱动已配置udev规则，普通用户无需sudo即可访问CAN接口。

## 📚 参考文档

- 官方readme: `drivers/usbcanfd200_400u_2.10/readme.txt`
- SocketCAN文档: https://www.kernel.org/doc/html/latest/networking/can.html
- ZLG官网: https://www.zlg.cn/
