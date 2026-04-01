# Blueberry S4 - AGENTS.md

> This file is intended for AI coding agents. It provides essential information about the project structure, build process, and development conventions.

## Project Overview

**Blueberry S4** is a mobile manipulation robot project based on ROS2 Humble. It integrates multiple hardware components for autonomous mobile manipulation tasks.

### Hardware Components

| Component | Manufacturer | Model | Interface | Protocol | Status |
|-----------|--------------|-------|-----------|----------|--------|
| AGV Chassis | YUHESEN | FW-Max | CAN 2.0 | Custom | ✅ Active |
| Lifter | RealMan | WHJ | CAN-FD | CANopen | ✅ Active |
| Servo | Kinco | FD1X5 | CAN-FD | CANopen | ✅ Active |
| Cameras | Intel | RealSense D405×7 | USB 3.0 | - | ⏳ Planned |
| LiDAR | Livox | Mid-360 | Ethernet | - | ⏳ Planned |

### Platform
- **Framework**: ROS2 Humble
- **OS**: Ubuntu 22.04 (Jetson)
- **Languages**: Python 3.10, C++17
- **Build Tool**: colcon
- **License**: MIT

---

## Directory Structure

```
Blueberry_s4/                    # ROS2 Workspace Root
├── src/                         # Source Code
│   ├── bringup/                 # Main launch package (entry point)
│   │   ├── launch/
│   │   │   └── robot.launch.py      # Main launch file
│   │   ├── config/
│   │   │   ├── robot.yaml           # Robot parameters
│   │   │   └── s4.rviz              # RViz configuration
│   │   └── test/                    # Unit tests
│   │
│   ├── YUHESEN-FW-MAX/          # Third-party AGV driver
│   │   ├── yhs_can_control/     # AGV CAN control node (C++)
│   │   │   ├── src/yhs_can_control_node.cpp
│   │   │   └── params/cfg.yaml
│   │   └── yhs_can_interfaces/  # AGV message definitions
│   │       └── msg/
│   │           ├── CtrlCmd.msg
│   │           ├── CtrlFb.msg
│   │           ├── IoCmd.msg
│   │           └── ...
│   │
│   ├── REALMAN-WHJ/             # WHJ lifter drivers
│   │   ├── whj_can_py/          # WHJ Python driver (ACTIVE)
│   │   │   ├── whj_can_py/whj_can_node.py
│   │   │   ├── core/
│   │   │   │   ├── socketcan_driver.py
│   │   │   │   ├── zlgcan_driver.py
│   │   │   │   └── protocol/whj_protocol.py
│   │   │   └── drivers/
│   │   │       ├── whj_driver.py
│   │   │       └── whj_motor_control.py
│   │   ├── whj_can_control/     # WHJ C++ driver (alternative)
│   │   └── whj_can_interfaces/  # WHJ message definitions
│   │       └── msg/
│   │           ├── WhjCmd.msg
│   │           └── WhjState.msg
│   │
│   ├── KINCO/                   # Kinco servo drivers
│   │   ├── kinco_can_control/   # Kinco C++ driver
│   │   │   └── src/kinco_can_control_node.cpp
│   │   └── kinco_can_interfaces/# Kinco message definitions
│   │       └── msg/
│   │           ├── KincoCmd.msg
│   │           └── KincoState.msg
│   │
│   ├── hardware/                # Hardware abstraction (placeholder)
│   ├── navigation/              # Navigation algorithms (placeholder)
│   └── perception/              # Perception algorithms (placeholder)
│
├── scripts/                     # Utility Scripts
│   └── s4                       # Main CLI (check/dev/build/stop/status)
│
├── config/                      # Hardware Configuration
│   ├── hardware_profile.yaml    # Hardware parameters
│   ├── can_devices.yaml         # CAN device configuration
│   └── config_loader.py         # Configuration tool
│
├── web_dashboard/               # Web-based monitoring
│   ├── s4_dashboard.html        # Main dashboard (AGV + WHJ control)
│   ├── agv_test_control.html    # AGV test interface
│   ├── app.js                   # JavaScript backend
│   └── style.css                # Styling
│
├── drivers/                     # CAN Driver Source
│   └── peak-linux-driver-8.18.0/# PEAK USB-CAN driver source
│
├── docs/                        # Documentation
│   ├── architecture_recommendation.md
│   ├── ros2_setup/
│   ├── can_design/
│   └── deployment/
│
├── build/                       # Build output (auto-generated)
├── install/                     # Install files (auto-generated)
└── log/                         # Build logs (auto-generated)
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

| Device | Interface | Driver | Bitrate | CAN IDs |
|--------|-----------|--------|---------|---------|
| FW-Max AGV | CAN 2.0 | pcan (PEAK) | 500K | 0x18C4D1D0 (TX), 0x98C4D1EF (RX) |
| RealMan WHJ | CAN-FD | usbcanfd (ZLG) | 1M/5M | Node ID 7 |
| Kinco Servo | CAN-FD | usbcanfd (ZLG) | 1M/5M | Node ID 1 |

### CAN Message IDs (AGV)

All AGV CAN IDs use **29-bit extended frame format**.

| Direction | CAN ID | Description |
|-----------|--------|-------------|
| TX | `0x18C4D1D0` | Motion control command |
| TX | `0x18C4D2D0` | Steering control command |
| TX | `0x18C4D7D0` | IO control command |
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

---

## Build Instructions

### Prerequisites

```bash
# Install ROS2 Humble (Ubuntu 22.04)
sudo apt install ros-humble-desktop
sudo apt install python3-colcon-common-extensions python3-rosdep

# Load ROS2 environment
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
# 1. Initialize hardware (needs sudo)
sudo ./scripts/s4 init

# 2. Build project
./scripts/s4 build

# 3. Start development environment
./scripts/s4 dev          # Hardware mode
./scripts/s4 dev sim      # Simulation mode
./scripts/s4 dev teleop   # Hardware + keyboard control

# Other commands
./scripts/s4 stop         # Stop all nodes
./scripts/s4 status       # View system status
```

### Manual Start

```bash
# 1. Source environment
source install/setup.bash

# 2. Launch main system
ros2 launch bringup robot.launch.py

# With parameters
ros2 launch bringup robot.launch.py sim:=true
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
| `can_agv_interface` | `can_agv` | CAN interface for AGV (logical name) |
| `can_devices_interface` | `can_fd` | CAN interface for WHJ+Kinco (logical name) |

---

## CAN Device Management

### Logical Names

S4 uses **logical names** to identify CAN devices, avoiding confusion from changing physical interface names:

| Logical Name | Physical Device | Purpose |
|--------------|-----------------|---------|
| `can_agv` | PEAK PCAN-USB | AGV (YUHESEN FW-Max) @ 500K |
| `can_fd` | ZLG CANFD | WHJ + Kinco @ 1M/5M CAN-FD |

The mapping is auto-detected by `sudo ./s4 init` and stored in `/tmp/s4_can_mapping.conf`.

### Quick Commands

```bash
# Check CAN status and device mapping
./scripts/s4 status

# Initialize and auto-configure all CAN devices
sudo ./scripts/s4 init

# View mapping file
cat /tmp/s4_can_mapping.conf
```

### Manual CAN Configuration

```bash
# PEAK PCAN-USB (AGV) - 500K
sudo ip link set can3 up type can bitrate 500000

# ZLG CANFD (WHJ + Kinco) - 1M/5M
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on
```

---

## Code Organization

### Package Structure

#### bringup (Main Package)
- **Type**: ament_python
- **Purpose**: Main entry point, launch files, configurations
- **Key Files**:
  - `launch/robot.launch.py` - Main launch file
  - `config/robot.yaml` - Robot parameters
  - `layouts/s4_default.json` - Foxglove layout

#### yhs_can_control (AGV Driver)
- **Type**: ament_cmake (C++)
- **Purpose**: YUHESEN FW-Max AGV control
- **Key Files**:
  - `src/yhs_can_control_node.cpp` - Main control node
  - `params/cfg.yaml` - Node parameters
- **Topics**:
  - Subscribers: `/ctrl_cmd`, `/io_cmd`, `/steering_ctrl_cmd`
  - Publishers: `/chassis_info_fb`, `/odom`

#### whj_can_py (WHJ Driver - ACTIVE)
- **Type**: ament_python
- **Purpose**: RealMan WHJ lifter control with trajectory planning
- **Key Files**:
  - `whj_can_py/whj_can_node.py` - ROS2 node
  - `core/socketcan_driver.py` - SocketCAN driver
  - `drivers/whj_driver.py` - WHJ motor driver
  - `core/protocol/whj_protocol.py` - Protocol definitions
- **Topics**:
  - Subscriber: `/whj_cmd`
  - Publisher: `/whj_state`

#### kinco_can_control (Kinco Driver)
- **Type**: ament_cmake (C++)
- **Purpose**: Kinco servo motor control
- **Key Files**:
  - `src/kinco_can_control_node.cpp` - Main control node
- **Topics**:
  - Subscriber: `/kinco_cmd`
  - Publisher: `/kinco_state`

### Interface Packages

Each driver has a corresponding interfaces package defining custom ROS2 messages:
- `yhs_can_interfaces/` - AGV messages
- `whj_can_interfaces/` - WHJ messages  
- `kinco_can_interfaces/` - Kinco messages

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

### Test Files

- `src/bringup/test/test_copyright.py` - Copyright header check
- `src/bringup/test/test_flake8.py` - Python style check
- `src/bringup/test/test_pep257.py` - Docstring check

### CAN Testing

```bash
# Check CAN status
./scripts/s4 status

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
- Follow **PEP 8**
- Use type hints where appropriate
- Docstrings in **Chinese** (following existing code)
- Maximum line length: 100 characters

#### C++
- Follow **ROS2 C++ style guidelines**
- Use `snake_case` for variables and functions
- Use `PascalCase` for classes
- Use 2-space indentation

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

## Web Dashboard

### Start Web Dashboard

```bash
# Automatic (via s4 dev)
./scripts/s4 dev

# Manual
bash web_dashboard/start_web_dashboard.sh
```

### Access

Open browser and navigate to: `http://<jetson-ip>:8080`

### Features
- Real-time AGV status (speed, angle, voltage, current)
- WHJ lifter control with trajectory planning
- ROS2 topic monitoring
- WebSocket connection to ROS2 (via rosbridge)

---

## Common Issues

### Issue: CAN interface not found
**Solution**:
```bash
sudo modprobe can can_raw can_dev
sudo ./scripts/s4 init
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

### Issue: WHJ motor fails to enable
**Solution**:
- Check CAN-FD interface is up: `ip link show can_fd`
- Verify motor is powered on
- Check motor ID configuration (default: 7)

### Issue: Kinco servo no response
**Solution**:
- Verify CAN interface: `candump can_agv`
- Check node ID (default: 1)
- Send NMT start: `cansend can_agv 000#0100`

---

## Remote Visualization

### Web Dashboard (Recommended)
```bash
# On Jetson
./scripts/s4 dev

# Access via browser
http://<jetson-ip>:8080
```

### Foxglove Studio
```bash
# On Jetson
ros2 launch rosbridge_server rosbridge_websocket_launch.xml

# Connect from browser
# URL: https://studio.foxglove.dev
# WebSocket: ws://<jetson-ip>:9091
```

### RViz via SSH X11
```bash
# Local computer
ssh -X hkclr@<jetson-ip>
bash ~/Blueberry_s4/launch_rviz_full.sh
```

---

## Deployment

### Jetson Deployment

```bash
# 1. Clone project
cd ~/Blueberry_s4

# 2. Check environment
./scripts/s4 status

# 3. Compile
./scripts/s4 build

# 4. Configure CAN (needs sudo)
sudo ./scripts/s4 init

# 5. Start
./scripts/s4 dev
```

### Environment Variables

```bash
# Required for isolated operation
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0
source ~/Blueberry_s4/install/setup.bash
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

*Last Updated: 2026-04-01*
