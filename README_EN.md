# Blueberry S4 - Mobile Manipulation Robot

**[简体中文](./README.md) | English**

[![ROS2](https://img.shields.io/badge/ROS2-Humble-blue)](https://docs.ros.org/en/humble/)
[![Python](https://img.shields.io/badge/Python-3.10-3776ab)](https://www.python.org/)
[![C++](https://img.shields.io/badge/C++-17-00599c)](https://isocpp.org/)

YUHESEN FW-Max AGV + RealMan WHJ Lifter + Kinco Rotation Servo + 7× RealSense D405 + Livox Mid-360

---

## 🚀 30-Second Quick Start

### Prerequisites
- Ubuntu 22.04 (Jetson)
- ROS2 Humble installed
- CAN hardware connected

> ⚠️ **WARNING: Driver Installation is Required Before Startup**
>
> **You MUST ensure that kernel drivers in the `drivers/` directory are properly compiled, installed, and loaded BEFORE starting the project.** This is a prerequisite for the entire project to run correctly. Without the drivers, CAN devices will not be recognized, causing hardware communication failures.
>
> Verification: `lsmod | grep -E "pcan|usbcanfd"` should show drivers are loaded
>
> See [1.2 Build CAN Drivers](#12-build-can-drivers-if-needed) section below

### 1. Clone and Build

#### 1.1 Clone the Repository

```bash
git clone https://github.com/licher255/blueberry_s4.git
cd blueberry_s4
```

#### 1.2 Build CAN Drivers (if needed)

If PEAK or ZLG drivers are not pre-installed on your system, you need to build them:

**PEAK USB-CAN Driver** (for AGV):
```bash
cd drivers/peak-linux-driver-8.18.0
make
sudo make install
sudo modprobe pcan
cd ../..
```

**ZLG USB-CANFD Driver** (for WHJ/Kinco):
```bash
# Use the auto-install script
sudo ./drivers/install_zlg_socketcan.sh

# Or build manually
cd drivers/zlg_usbcanfd_2_10
make
sudo insmod usbcanfd.ko
cd ../..
```

**Verify Drivers**:
```bash
lsmod | grep -E "pcan|usbcanfd"
# Should show pcan and/or usbcanfd
```

#### 1.3 Build ROS2 Packages

```bash
source /opt/ros/humble/setup.bash

# Clean (if needed)
rm -rf build install log

# Build all packages (including C++ drivers)
colcon build --symlink-install

# Source the built environment
source install/setup.bash
```

**Build Contents**:
- `yhs_can_control` - AGV C++ driver
- `whj_can_control` - WHJ C++ driver (backup)
- `kinco_can_control` - Kinco C++ driver
- `bringup` - Launch package
- `*_interfaces` - Message interface packages

### 2. Initialize CAN Devices (requires sudo)

```bash
sudo ./scripts/s4 init
```

> ⚠️ **WARNING: Before running this step, make sure drivers are installed!**
>
> If `lsmod | grep -E "pcan|usbcanfd"` shows no output, please complete [1.2 Build CAN Drivers](#12-build-can-drivers-if-needed) first.

This will:
- Load CAN kernel modules
- Configure all CAN interfaces (auto-detect baud rates)
- Establish device mapping (PEAK→AGV, ZLG→WHJ/Kinco)

### 3. Launch the Full System

```bash
./scripts/s4 dev
```

The browser will automatically open `http://localhost:8080`. Use WASD to control the AGV, and sliders to control the WHJ lifter and Kinco rotation.

**Stop**: Press `Ctrl+C`, which will automatically disable motor enable signals.

---

## 📦 Project Structure

```
blueberry_s4/
├── src/
│   ├── bringup/                    # Main launch package
│   │   ├── launch/robot.launch.py  # System launch entry
│   │   └── config/robot.yaml       # Global parameters
│   │
│   ├── YUHESEN-FW-MAX/             # ✅ AGV driver (third-party)
│   │   ├── yhs_can_control/        # C++ CAN control node
│   │   └── yhs_can_interfaces/     # AGV message definitions
│   │
│   ├── REALMAN-WHJ/                # ✅ WHJ driver (completed)
│   │   ├── whj_can_py/             # Python driver (recommended)
│   │   │   ├── whj_can_py/whj_can_node.py      # ROS2 node
│   │   │   ├── core/socketcan_driver.py        # SocketCAN driver
│   │   │   ├── core/zlgcan_driver.py           # ZLG CANFD driver
│   │   │   ├── core/protocol/whj_protocol.py   # WHJ protocol
│   │   │   └── drivers/whj_driver.py           # WHJ motor control
│   │   ├── whj_can_control/        # C++ driver (backup)
│   │   └── whj_can_interfaces/     # WHJ message definitions
│   │
│   ├── KINCO/                      # ✅ Kinco driver (completed)
│   │   ├── kinco_can_control/      # C++ CANopen node
│   │   │   └── src/kinco_can_control_node.cpp    # Main control node
│   │   └── kinco_can_interfaces/   # Kinco message definitions
│   │
│   ├── hardware/                   # Hardware abstraction layer (reserved)
│   ├── perception/                 # Perception algorithms (reserved)
│   └── navigation/                 # Navigation algorithms (reserved)
│
├── scripts/
│   └── s4                           # Main CLI tool
│
├── web_dashboard/
│   └── s4_dashboard.html            # Web control dashboard
│
└── drivers/
    └── peak-linux-driver-8.18.0/    # PEAK USB-CAN driver source
```

---

## 🔌 Hardware Connections

### Device List

| Device | Model | Interface | Status |
|--------|-------|-----------|--------|
| AGV Chassis | YUHESEN FW-Max | PEAK USB-CAN | ✅ Integrated |
| Lifter | RealMan WHJ | ZLG CANFD | ✅ Integrated |
| Rotation Motor | Kinco FD1X5 | ZLG CANFD | ✅ Integrated |
| Depth Cameras | Intel D405×7 | USB 3.0 | ⏳ Reserved |
| LiDAR | Livox Mid-360 | Ethernet | ⏳ Reserved |

### Physical Connections

```
Jetson
├── PEAK USB-CAN  →  YUHESEN FW-Max AGV (500K)
│                     CAN ID: 0x18C4xxxx
│
├── ZLG CANFD     →  RealMan WHJ (1M/5M CAN-FD)
│                     Node ID: 7
│                     ↓
└── (Same bus)    →  Kinco FD1X5 (1M/5M CAN-FD)
                      Node ID: 1
```

### Dual-CAN Architecture Explanation

**Why do we need two CAN interfaces?**

| Interface | Driver | Device | Baud Rate | Reason |
|-----------|--------|--------|-----------|--------|
| PEAK (can_agv) | pcan | AGV | 500K | AGV only supports standard CAN 500K |
| ZLG (can_fd) | usbcanfd | WHJ+Kinco | 1M/5M | WHJ/Kinco require CAN-FD high-speed communication |

**Baud Rate Incompatibility**: The AGV uses standard CAN 500K, while WHJ/Kinco use CAN-FD 1M (arbitration) / 5M (data). They cannot share the same bus.

---

## 🛠️ S4 CLI Tool Details

### Full Command List

```bash
./scripts/s4 [command] [options]
```

| Command | Function | Example |
|---------|----------|---------|
| `init` | Initialize CAN devices (requires sudo) | `sudo ./scripts/s4 init` |
| `build` | Build the workspace | `./scripts/s4 build` |
| `build clean` | Clean and build | `./scripts/s4 build clean` |
| `dev` | Start development environment | `./scripts/s4 dev` |
| `dev sim` | Simulation mode | `./scripts/s4 dev sim` |
| `dev teleop` | Hardware + keyboard teleop | `./scripts/s4 dev teleop` |
| `stop` | Stop all nodes | `./scripts/s4 stop` |
| `status` | View system status | `./scripts/s4 status` |
| `help` | Show help | `./scripts/s4 help` |

### Command Details

#### `s4 init` - Initialize Hardware

```bash
sudo ./scripts/s4 init
```

Execution flow:
1. Load CAN kernel modules (`can`, `can_raw`, `can_dev`)
2. Load PEAK and ZLG drivers (`peak_usb`, `usbcanfd`)
3. Detect all CAN interfaces and configure baud rates
4. Create device mapping file `/tmp/s4_can_mapping.conf`

Example output:
```
✓ Module can loaded
✓ Module can_raw loaded
✓ can3 @ 500Kbps (pcan)        ← AGV (PEAK)
✓ can2 @ 1000Kbps (usbcanfd)    ← WHJ/Kinco (ZLG)
✓ can_agv (AGV)  -> can3
✓ can_fd (WHJ)   -> can2
```

#### `s4 build` - Build Project

```bash
./scripts/s4 build              # Normal build
./scripts/s4 build clean        # Clean build
./scripts/s4 build --packages-select bringup    # Build bringup only
```

Automatically performs:
1. Load ROS2 environment
2. Install dependencies (`rosdep install`)
3. Build (`colcon build --symlink-install`)

#### `s4 dev` - Start Development Environment

```bash
./scripts/s4 dev        # Hardware mode (start AGV+WHJ+Kinco)
./scripts/s4 dev sim    # Simulation mode (no real hardware)
./scripts/s4 dev teleop # Hardware + keyboard teleop (requires display)
```

**Hardware Mode** (`dev`) startup flow:
1. Read CAN device mapping
2. Start Web server (port 8080)
3. Start AGV node (`ros2 launch bringup robot.launch.py`)
4. Start WHJ node (`ros2 run whj_can_py whj_can_node`)
5. Start Kinco node (`ros2 run kinco_can_control kinco_can_control_node`)
6. Start Rosbridge (port 9091)
7. Open browser

**Stop** (`Ctrl+C`):
1. Send CAN frame to disable WHJ (`007#020A0000`)
2. Send CAN frame to disable Kinco (`201#0106100000000000`)
3. Terminate all ROS2 processes

#### `s4 status` - View Status

```bash
./scripts/s4 status
```

Displays:
- CAN interface status and mapping
- ROS2 node running status
- Process PIDs

---

## 🎮 User Guide

### Web Dashboard Control

After startup, open `http://<jetson-ip>:8080` in your browser.

**UI Layout**:
```
┌─────────────────────────────────────────┐
│ 🔗 ROS2 Connection [Connect/Disconnect] │  ← Row 1: Connection
├─────────────────────────────────────────┤
│ 🚗 AGV Status │ 🛗 WHJ Status │ ⚙️ Kinco Status │  ← Row 2: Status
├─────────────────────────────────────────┤
│ AGV Error │ WHJ Error │ Kinco Error [Clear]    │  ← Row 3: Errors
├─────────────────────────────────────────┤
│    🎮 AGV Control    │  🛗 WHJ Control        │  ← Row 4: Control
│  [Arrow keys]        │  [Slider + Button]     │
│  [Emergency Stop]    │  ⚙️ Kinco Control      │
│                      │  [Slider + Preset Angles]│
└─────────────────────────────────────────┘
```

**Operation Steps**:
1. Click the "Connect" button to connect to ROS2
2. AGV: Hold WASD or arrow keys to control, release to stop
3. WHJ: Drag the slider to set target position (0-900mm), click "Move"
4. Kinco: Drag the slider or click preset angles (0°/90°/180°), click "Move"

### Keyboard Teleop (teleop mode)

```bash
./scripts/s4 dev teleop
```

Key mappings:
| Key | Function |
|-----|----------|
| W / ↑ | Forward |
| S / ↓ | Backward |
| A / ← | Turn left / left translate |
| D / → | Turn right / right translate |
| Space | Emergency stop |
| Q | Quit |

**Requires a local display** (not supported over SSH).

---

## 🔧 Troubleshooting

### Issue 1: Driver Not Loaded (Most Common)

**Symptom**: `lsusb` shows the device, but `s4 init` reports driver not loaded

**Solution**:
```bash
# Check if drivers are loaded
lsmod | grep -E "pcan|usbcanfd"

# If no output, build and install drivers

# PEAK driver (AGV)
cd drivers/peak-linux-driver-8.18.0
make clean && make
sudo make install
sudo modprobe pcan

# ZLG driver (WHJ/Kinco)
cd drivers/zlg_usbcanfd_2_10
make
sudo insmod usbcanfd.ko

# Verify
cd ~/Blueberry_s4
lsmod | grep -E "pcan|usbcanfd"
# Should now show drivers loaded
```

### Issue 2: CAN Device Not Found

```bash
# Check USB devices
lsusb | grep -i "peak\|zlg"

# Manually load drivers
sudo modprobe can can_raw can_dev peak_usb usbcanfd

# Re-initialize
sudo ./scripts/s4 init
```

### Issue 2: AGV Not Responding

```bash
# Check CAN data
candump can3

# Check ROS2 topics
ros2 topic echo /chassis_info_fb

# Send test command manually
ros2 topic pub /ctrl_cmd yhs_can_interfaces/msg/CtrlCmd \
  '{ctrl_cmd_x_linear: 0.1, ctrl_cmd_gear: 6}'
```

### Issue 3: WHJ/Kinco No Response

```bash
# Check CAN-FD data
candump can2

# Check node status
ros2 node list | grep -i whj
ros2 topic echo /whj_state

# Manually enable WHJ
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, enable: true}'
```

### Issue 4: Build Failure

```bash
# Fully clean and rebuild
rm -rf build install log
source /opt/ros/humble/setup.bash
colcon build --symlink-install

# Check dependencies
rosdep install --from-paths src --ignore-src -y
```

---

## 📝 Development Notes

### Adding a New Hardware Driver

Create a new package under `src/`:

```bash
cd src
ros2 pkg create my_hardware --build-type ament_python
cd ..
colcon build --packages-select my_hardware
```

### Modifying Existing Drivers

**WHJ Driver** (`src/REALMAN-WHJ/whj_can_py/`):
- Node entry: `whj_can_py/whj_can_node.py`
- Protocol definition: `core/protocol/whj_protocol.py`
- Motor control: `drivers/whj_driver.py`

**Kinco Driver** (`src/KINCO/kinco_can_control/`):
- Main node: `src/kinco_can_control_node.cpp`
- Protocol: CANopen (NMT, PDO, SDO)

**AGV Driver** (`src/YUHESEN-FW-MAX/`):
- Third-party driver, do not modify

---

## 📚 Documentation

- [PROJECT_LOG.md](./PROJECT_LOG.md) - Detailed development log
- [AGENTS.md](./AGENTS.md) - AI agent configuration guide
- [docs/setup/](./docs/setup/) - Environment setup guide
- [docs/hardware/](./docs/hardware/) - Hardware manuals

---

## 📄 License

MIT License - See [LICENSE](LICENSE)

---

*Last Updated: 2026-04-01*
