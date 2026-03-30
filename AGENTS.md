# Blueberry S4 - AGENTS.md

> This file is intended for AI coding agents. It provides essential information about the project structure, build process, and development conventions.

## Project Overview

**Blueberry S4** is a mobile manipulation robot project based on ROS2 Humble. It integrates:

- **Chassis**: YUHESEN FW-Max AGV (4-wheel steering mobile robot)
- **Lifter**: RealMan WHJ lifting mechanism
- **Servo**: Kinco servo system
- **Vision**: 7× Intel RealSense D405 depth cameras
- **Lidar**: Livox Mid-360 LiDAR
- **Platform**: NVIDIA Jetson (Ubuntu 22.04)

### Project Type
- **Framework**: ROS2 Humble
- **Language**: Python 3.10 + C++
- **Build Tool**: colcon
- **License**: MIT

---

## Directory Structure

```
Blueberry_s4/                    # ROS2 Workspace Root
├── src/                         # Source Code
│   ├── bringup/                 # Main launch package (entry point)
│   ├── hardware/                # Hardware abstraction layer (placeholder)
│   ├── navigation/              # Navigation algorithms (placeholder)
│   ├── perception/              # Perception algorithms (placeholder)
│   ├── YUHESEN-FW-MAX/          # Third-party: YUHESEN official driver
│   │   ├── yhs_can_control/     # AGV CAN control node (C++)
│   │   └── yhs_can_interfaces/  # AGV message definitions
│   └── YUHESEN-FW-MAX.bak/      # Backup of old driver version
│
├── drivers/                     # CAN Driver Source Code
│   └── peak-linux-driver-8.18.0/# PEAK USB-CAN driver source
│
├── scripts/                     # Utility Scripts
│   ├── s4                       # Main CLI (tauri-style: check/dev/build/stop/status/can)
│   └── can_manager.sh           # CAN device manager (internal tool)
│
├── config/                      # Hardware Configuration
│   ├── hardware_profile.yaml    # Hardware parameters
│   └── config_loader.py         # Configuration tool
│
├── docs/                        # Documentation
│   ├── setup/                   # Environment setup guides
│   ├── hardware/                # Hardware manuals
│   ├── deployment/              # Deployment guides
│   └── can_design/              # CAN architecture design
│
├── build/                       # Build output (auto-generated)
├── install/                     # Install files (auto-generated)
├── log/                         # Build logs (auto-generated)
└── PROJECT_LOG.md               # Development log (Chinese)
```

---

## Technology Stack

### Core Dependencies
| Package | Purpose | Version |
|---------|---------|---------|
| ROS2 Humble | Robot middleware | Latest |
| rclpy | Python client library | Humble |
| rclcpp | C++ client library | Humble |
| python-can | CAN bus interface | Latest |
| can-utils | CAN debugging tools | Latest |

### Hardware Interfaces
| Device | Interface | Protocol | Bitrate |
|--------|-----------|----------|---------|
| FW-Max AGV | CAN 2.0 | Custom | 500K |
| RealMan WHJ | CAN-FD | CANopen | 1M/5M |
| Kinco Servo | CAN-FD | CANopen | 1M |

---

## Build Instructions

### Prerequisites
```bash
# 安装 ROS2 Humble (如果未安装)
# 参考: https://docs.ros.org/en/humble/Installation.html
# Ubuntu 22.04:
#   sudo apt install ros-humble-desktop
#   sudo apt install python3-colcon-common-extensions python3-rosdep

# 加载 ROS2 环境
source /opt/ros/humble/setup.bash
```

### Build Commands
```bash
cd ~/Blueberry_s4

# Full build
colcon build --symlink-install

# Build specific package
colcon build --packages-select bringup --symlink-install

# Clean build
rm -rf build install log
colcon build --symlink-install

# Source environment
source install/setup.bash
```

### Dependency Installation
```bash
# Update rosdep
rosdep update

# Install dependencies
rosdep install --from-paths src --ignore-src -y
```

---

## Run Instructions

### Quick Start (Recommended)
```bash
# 推荐使用方式 (类似 tauri cli)
./scripts/s4 check           # 检查环境和依赖
./scripts/s4 dev             # 启动开发环境 (硬件模式)
./scripts/s4 dev sim         # 仿真模式
./scripts/s4 dev teleop      # 硬件 + 键盘遥控

# 其他命令
./scripts/s4 build           # 编译工作空间
./scripts/s4 build clean     # 清理并编译
./scripts/s4 stop            # 停止所有节点
./scripts/s4 status          # 查看系统状态
sudo ./scripts/s4 can auto   # 自动配置 CAN 设备
```

### Manual Start
```bash
# 1. Configure CAN (if not using s4 dev)
sudo ./scripts/s4 can auto

# 2. Source environment
source install/setup.bash

# 3. Launch
ros2 launch bringup robot.launch.py

# With parameters
ros2 launch bringup robot.launch.py sim:=true
# 手动指定物理接口 (不推荐，建议用 s4 init 自动配置)
ros2 launch bringup robot.launch.py can_agv_interface:=can3 can_devices_interface:=can2
```

### Launch Arguments
| Argument | Default | Description |
|----------|---------|-------------|
| `sim` | `false` | Enable simulation mode |
| `use_agv` | `true` | Enable AGV |
| `use_whj` | `true` | Enable WHJ lifter |
| `use_kinco` | `true` | Enable Kinco servo |
| `use_cameras` | `false` | Enable D405 cameras |
| `use_lidar` | `false` | Enable Livox lidar |
| `can_agv_interface` | `can_agv` | CAN interface for AGV (PEAK PCAN-USB) |
| `can_devices_interface` | `can_fd` | CAN interface for WHJ+Kinco (ZLG CANFD) |

> **说明**: `can_agv` 和 `can_fd` 是逻辑名，运行 `sudo ./s4 init` 后会自动映射到实际的物理接口 (can2/can3 等)。

---

## Code Organization

### Package Structure

#### bringup (Main Package)
```
src/bringup/
├── bringup_module/          # Python package
├── launch/
│   └── robot.launch.py      # Main launch file
├── config/
│   ├── robot.yaml           # Robot parameters
│   └── s4.rviz              # RViz configuration
├── layouts/
│   └── s4_default.json      # Foxglove layout
└── test/                    # Unit tests
```

#### yhs_can_control (Third-party AGV Driver)
```
src/YUHESEN-FW-MAX/yhs_can_control/
├── src/
│   └── yhs_can_control_node.cpp    # Main C++ node
├── include/yhs_can_control/
│   └── yhs_can_control_node.hpp    # Header file
├── launch/
│   └── yhs_can_control.launch.py   # Launch file
├── params/
│   └── cfg.yaml                    # Node parameters
└── package.xml
```

#### yhs_can_interfaces (AGV Messages)
```
src/YUHESEN-FW-MAX/yhs_can_interfaces/
├── msg/                     # Message definitions
│   ├── CtrlCmd.msg         # Control command
│   ├── CtrlFb.msg          # Control feedback
│   ├── IoCmd.msg           # IO command
│   ├── IoFb.msg            # IO feedback
│   ├── ChassisInfoFb.msg   # Chassis info
│   └── ...
└── CMakeLists.txt
```

### CAN Message IDs (AGV)

| Direction | CAN ID | Description |
|-----------|--------|-------------|
| TX | `0x98C4D1D0` | Motion control command |
| TX | `0x98C4D2D0` | Steering control command |
| TX | `0x98C4D7D0` | IO control command |
| RX | `0x98C4D1EF` | Control feedback |
| RX | `0x98C4D2EF` | Steering feedback |
| RX | `0x98C4D6EF` | Left front wheel feedback |
| RX | `0x98C4D7EF` | Left rear wheel feedback |
| RX | `0x98C4D8EF` | Right rear wheel feedback |
| RX | `0x98C4D9EF` | Right front wheel feedback |
| RX | `0x98C4DAEF` | IO feedback |
| RX | `0x98C4DCEF` | Front angle feedback |
| RX | `0x98C4DDEF` | Rear angle feedback |
| RX | `0x98C4E1EF` | BMS feedback |
| RX | `0x98C4E2EF` | BMS flag feedback |

IO使能控制需要发送使能标志位，心跳信息和校验位 io_cmd_unlock 安全解锁开关0x02, 需要一下型号下降沿间隔20ms下发， 可以请求解锁安全停车开关。 
|ID        | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 |
|0x18C4D7D0|0x02|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x02|
|0x18C4D7D0|0x02|0x00|0x00|0x00|0x00|0x00|0x00|0x10|0x12|
|0x18C4D7D0|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x20|0x20|
|0x18C4D7D0|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x30|0x30|

反馈消息如下 

|ID        | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | D8 |
|0x18C4DAEF|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x02|
|0x18C4DAEF|0x02|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x02|
|0x18C4DAEF|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x00|0x02|

ctrl_cmd示例如下：
目标档位信号值为0~3bit，物理值范围为：00至08，默认目标档位为00即disable
档：目标档位给定为01时为驻车档；目标档位给定02时为空档：目标档位给定06时为4T4D档：目标档位给定08时为横移档。在ctrl_cmd消息下目标档位给定05或07无效。
例1：目标档位请求为4T4D档（06）时，车辆为四转四驱模式：
目标×轴线速度为0.001m/s/bit总线信号，若想要请求0.5m/s的目标X轴线速度，则总线信号为500（0x01F4），X轴线速度值向前为正，向后为负；
目标Z轴角速度为0.01%/s/bit*总线信号，若想要请求-25%/s的目标Z轴角速度，则总线信号为-2500（0xF63C），从正上方俯视车辆，Z轴角速度逆时针为正，顺时针为负；
目标Y轴线速度此档位时无效，默认填0（0×0000）即可。

|ID        | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 |
|0x18C4D1D0|0x46|0x1F|0xC0|0x63|0x0F|0x00|0x10|0xE5|
|0x18C4D1D0|0x46|0x1F|0xC0|0x63|0x0F|0x00|0x20|0xD5|
|0x18C4D1D0|0x46|0x1F|0xC0|0x63|0x0F|0x00|0x30|0xC5|
以上三帧信息间隔10ms循环下发，可以控制车辆已0.5m/s的x轴线速度，-25°/s 的z轴角速度四转4驱模式运行。

反馈消息如下：
|ID        | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 |
|0x18C4D1EF|0x46|0x1F|0xC0|0x63|0x0F|0x00|0xA0|0x55|
|0x18C4D1EF|0x46|0x1F|0xC0|0x63|0x0F|0x00|0xB0|0x45|
|0x18C4D1EF|0x46|0x1F|0xC0|0x63|0x0F|0x00|0xC0|0x35|

异或校验和心跳信号循环变化，由于运行车速自动调节可能反馈值不是绝对的。

**Note**: All AGV CAN IDs use 29-bit extended frame format.

---

## Testing

### Run Tests
```bash
# Run all tests
cd ~/Blueberry_s4
source install/setup.bash
colcon test

# Run specific package tests
colcon test --packages-select bringup

# View test results
colcon test-result --verbose
```

### CAN Testing
```bash
# Check CAN status
./scripts/s4 can status

# Manual CAN test
candump can0

# Send test frame
cansend can0 123#DEADBEEF
```

### ROS2 Debugging
```bash
# List topics
ros2 topic list

# Echo topic
ros2 topic echo /chassis_info_fb
ros2 topic echo /ctrl_cmd

# Node info
ros2 node info /agv_node

# RViz
rviz2

# rqt_graph
rqt_graph
```

---

## Development Conventions

### Code Style

#### Python
- Follow PEP 8
- Use type hints where appropriate
- Docstrings in Chinese (following existing code)

#### C++
- ROS2 C++ style guidelines
- Use `snake_case` for variables and functions
- Use `PascalCase` for classes

### Package Naming
- Use `snake_case` for package names
- Custom packages: simple names (e.g., `bringup`)
- Hardware drivers: descriptive names (e.g., `yhs_can_control`)

### Launch Files
- Main launch: `robot.launch.py`
- Use `DeclareLaunchArgument` for parameters
- Include subsystem launches via `IncludeLaunchDescription`

### Configuration
- YAML files for parameters
- Hardware config: `config/hardware_profile.yaml`
- Robot config: `src/bringup/config/robot.yaml`

---

## CAN Device Management

### Supported Devices
| Device Type | Driver | Logical Name | Physical Interface |
|-------------|--------|--------------|-------------------|
| Jetson Built-in CAN | mttcan | - | can0/can1 |
| PEAK USB-CAN | pcan | `can_agv` | can2/can3 (auto-detected) |
| ZLG CAN-FD | usbcanfd | `can_fd` | can2/can3 (auto-detected) |

> **逻辑名说明**: 运行 `sudo ./s4 init` 后，系统会自动检测 USB-CAN 设备并创建映射文件 `/tmp/s4_can_mapping.conf`，将 `can_agv` 映射到 PEAK 设备，`can_fd` 映射到 ZLG 设备。

### Quick Commands
```bash
# Check CAN status and device mapping
./scripts/s4 status

# Initialize and auto-configure all CAN devices
sudo ./scripts/s4 init

# Install PEAK driver (if needed)
sudo ./scripts/s4 can install-driver
```

### CAN Device Mapping

S4 使用**逻辑名**来标识 CAN 设备，避免因 USB 枚举顺序变化导致接口名混乱：

```bash
# 查看当前映射
./scripts/s4 status

# 示例输出:
# CAN Device Mapping:
#   ● can_agv -> can3 (pcan)     # AGV (PEAK)
#   ● can_fd  -> can2 (usbcanfd) # WHJ + Kinco (ZLG)
```

**手动指定物理接口** (不推荐，除非你知道确切接口名):
```bash
ros2 launch bringup robot.launch.py can_agv_interface:=can3 can_devices_interface:=can2
```

### Auto-start Service (可选)
> 注意: `install_can_service.sh` 已被移除，如需开机自动配置 CAN，请手动创建 systemd 服务或使用 cron。

```bash
# 手动配置 CAN
sudo ./scripts/s4 can auto

# 或添加到 ~/.bashrc
# sudo ./scripts/s4 can auto
```

---

## Common Issues

### Issue: CAN interface not found
**Solution**:
```bash
sudo modprobe can can_raw can_dev
sudo ./scripts/s4 can auto
```

### Issue: Permission denied on CAN
**Solution**: Add user to can group or use sudo
```bash
sudo usermod -aG can $USER
# Logout and login again
```

### Issue: Package not found after build
**Solution**:
```bash
source install/setup.bash
# Or check if package.xml is correct
```

### Issue: xterm error in SSH
**Cause**: teleop_keyboard uses xterm which requires display
**Solution**: Run with `teleop:=false` or use local terminal
```bash
ros2 launch bringup robot.launch.py use_teleop:=false
```

---

## Remote Visualization

### Web Dashboard (Recommended)
```bash
# On Jetson
bash ~/s4_ws/web_dashboard/start_web_dashboard.sh

# Access via browser
http://<jetson-ip>:8080
```

### Foxglove Studio
```bash
# On Jetson
ros2 launch rosbridge_server rosbridge_websocket_launch.xml

# Connect from browser
# URL: https://studio.foxglove.dev
# WebSocket: ws://<jetson-ip>:9090 or :9091
```

### RViz via SSH X11
```bash
# Local computer
ssh -X hkclr@<jetson-ip>
bash ~/s4_ws/launch_rviz_full.sh
```

---

## Deployment

### Jetson Deployment
> 注意: 部署脚本已简化，建议直接使用 `./s4` 命令进行管理。

```bash
# 1. 克隆项目到 Jetson
cd ~/Blueberry_s4

# 2. 检查环境
./scripts/s4 check

# 3. 编译
./scripts/s4 build

# 4. 配置 CAN (需要 sudo)
sudo ./scripts/s4 can auto

# 5. 启动
./scripts/s4 dev
```

### Environment Variables
```bash
# Required for isolated operation
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0
source ~/s4_ws/install/setup.bash
```

---

## Documentation References

- [ROS2 Humble Docs](https://docs.ros.org/en/humble/)
- [PROJECT_LOG.md](./PROJECT_LOG.md) - Development history (Chinese)
- [docs/architecture_recommendation.md](./docs/architecture_recommendation.md) - System design
- [docs/can_design/can_architecture_comparison.md](./docs/can_design/can_architecture_comparison.md) - CAN design
- [docs/ros2_setup/ros2_beginner_guide.md](./docs/ros2_setup/ros2_beginner_guide.md) - ROS2 tutorial

---

## Contact & Contribution

- **Maintainer**: Blueberry Team
- **Email**: xuhao6815@gmail.com
- **License**: MIT

---

*Last Updated: 2026-03-24*
