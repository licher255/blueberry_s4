# RealMan WHJ Lifting Mechanism Driver

## Overview
ROS2 Humble driver for RealMan WHJ lifting mechanism using CAN-FD communication.

## Hardware Setup

### CAN Interface
- **Device**: ZLG USBCANFD-100U-mini
- **Connection**: USB
- **Protocol**: CAN-FD (1M/5M)

### Driver Installation

#### ZLG CAN-FD Driver
ZLG USBCANFD-100U-mini requires official driver from ZLG:

1. Download driver from ZLG official website:
   - https://www.zlg.cn/ (周立功官网)
   - Look for "USBCANFD系列驱动"

2. Install driver:
```bash
# Extract driver package
cd ~/Downloads
tar -xvf USBCANFD_LINUX_DRIVER.tar.gz
cd USBCANFD_LINUX_DRIVER

# Build and install
make
sudo insmod zlgcanfd.ko

# Make persistent
echo "zlgcanfd" | sudo tee -a /etc/modules
```

3. Verify installation:
```bash
ls /dev/zlgcanfd*
# or
ip link show | grep can
```

#### Alternative: Using SocketCAN driver (if supported)
Some ZLG devices support SocketCAN gs_usb driver:
```bash
sudo modprobe gs_usb
# Check if can3+ appears
ip link show
```

## Usage

### Quick Start
```bash
# Terminal 1: Configure CAN (需要先安装ZLG驱动)
cd ~/Blueberry_s4
sudo ./scripts/s4 can auto  # 自动配置所有CAN设备

# Terminal 2: Launch driver
source install/setup.bash
ros2 launch whj_can_control whj_can_control.launch.py can_interface:=can3
```

### Testing with Python Script (无需ROS2)
如果你还没有安装ZLG驱动，可以使用Python脚本测试：
```bash
# 进入脚本目录
cd ~/Blueberry_s4/src/RealMan-WHJ/whj_can_control/scripts

# 只监听CAN消息
python3 test_whj_can.py -i can1 -l

# 发送位置命令
python3 test_whj_can.py -i can1 -p 100 -s 50
```

### Using PCAN instead of ZLG (临时方案)
如果没有ZLG驱动，可以暂时使用PCAN设备进行测试：
```bash
# 配置PCAN接口
sudo ./scripts/s4 can setup can2 1000000

# 将WHJ连接到PCAN
# 使用WHJ驱动
ros2 launch whj_can_control whj_can_control.launch.py can_interface:=can2 canfd_enabled:=false
```

### Topics

#### Subscribers
- `/whj/position_cmd` (whj_can_interfaces/msg/PositionCmd)
  - Control WHJ position
- `/whj/velocity_cmd` (whj_can_interfaces/msg/VelocityCmd)
  - Control WHJ velocity

#### Publishers
- `/whj/state_fb` (whj_can_interfaces/msg/StateFb)
  - Combined state feedback
- `/whj/position_fb` (whj_can_interfaces/msg/PositionFb)
  - Position feedback
- `/whj/status_fb` (whj_can_interfaces/msg/StatusFb)
  - Status feedback

### Testing
```bash
# Test position command
ros2 topic pub /whj/position_cmd whj_can_interfaces/msg/PositionCmd \
  "{target_position: 100.0, target_speed: 50.0, control_mode: 0}" --once

# Monitor feedback
ros2 topic echo /whj/position_fb
```

## Protocol Notes

### CAN ID Assignment
- TX: 0x01 (Position command)
- TX: 0x02 (Velocity command)
- RX: 0x101 (Position feedback)
- RX: 0x102 (Status feedback)

### Data Format
> **Note**: This is placeholder format based on typical lifting mechanism protocols.
> Update `whj_can_control_node.cpp` according to actual WHJ protocol specification.

## Package Structure
```
RealMan-WHJ/
├── whj_can_interfaces/    # ROS2 message definitions
│   └── msg/
│       ├── PositionCmd.msg
│       ├── VelocityCmd.msg
│       ├── PositionFb.msg
│       ├── StatusFb.msg
│       └── StateFb.msg
├── whj_can_control/       # Control node
│   ├── src/
│   ├── include/
│   ├── launch/
│   └── params/
└── README.md
```

## Development

### Build
```bash
colcon build --packages-select whj_can_interfaces whj_can_control --symlink-install
```

### TODO
- [ ] Implement actual WHJ protocol (参考用户提供的Python代码)
- [ ] Add more safety checks
- [ ] Add calibration/ homing procedure
- [ ] Add diagnostic tools

## References
- RealMan WHJ Protocol Document (Python code at D:\Realman_joint\RealMan_Motor_Joint\examples\python)
- ZLG CAN-FD Documentation
