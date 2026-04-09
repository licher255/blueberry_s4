# RealMan WHJ Driver

[← Back to Index](./README.md) | [中文](./README_CN.md)

## Overview

ROS2 Humble driver for **RealMan WHJ Lifter Motor** with trapezoidal trajectory planning.
https://develop.realman-robotics.com/joints/CANFD/memoryControlTable/

**Key Features**:
- SocketCAN-based (no proprietary libraries)
- CAN-FD support (1M/5M)
- **Trapezoidal trajectory planning** - smooth motion, prevents errors on large moves
- Complete ROS2 interface

## 📁 Package Structure

```
REALMAN-WHJ/
├── whj_can_py/                     # Python driver (recommended)
│   ├── whj_can_py/
│   │   ├── core/
│   │   │   ├── socketcan_driver.py      # SocketCAN driver
│   │   │   └── protocol/whj_protocol.py # WHJ protocol
│   │   ├── drivers/whj_driver.py        # Motor driver with trajectory
│   │   ├── whj_can_node.py              # ROS2 node
│   │   └── __main__.py                  # Module entry
│   ├── launch/whj_can_py.launch.py      # Launch file
│   └── README.md                        # Detailed docs
│
├── whj_can_control/                # C++ driver (alternative)
│   └── src/whj_can_control_node.cpp     # C++ implementation
│
└── whj_can_interfaces/             # ROS2 message definitions
    └── msg/
        ├── WhjCmd.msg                   # Command message
        └── WhjState.msg                 # State message
```

**Recommendation**: Use Python driver (`whj_can_py`) for its trajectory planning feature.

## 🔌 Hardware Connection

| Parameter | Value |
|-----------|-------|
| **Interface** | ZLG CAN-FD (dedicated) |
| **Bitrate** | 1Mbps (arbitration) / 5Mbps (data) |
| **Node ID** | 7 (default) |
| **Frame Type** | CAN-FD |
| **Protocol** | RealMan custom protocol |

**Note**: WHJ uses dedicated CAN-FD bus separate from AGV/Kinco due to different bitrate requirements.

## 📡 Protocol

| Function | CAN ID | Description |
|----------|--------|-------------|
| **Read** | `0x07` | Read status/position |
| **Write** | `0x07` | Write commands |
| **Registers** | - | 0x0A (enable), 0x36/0x37 (position), 0x0F (clear error) |

## 💬 ROS2 Topics

### Subscribers
- **`/whj_cmd`** ([`WhjCmd.msg`](./whj_can_interfaces/msg/WhjCmd.msg))
  - `motor_id`: Motor ID (default: 7)
  - `target_position_deg`: Target position (degrees, 0-50000°)
  - `target_speed_rpm`: Target speed (RPM)
  - `target_current_ma`: Target current (mA)
  - `work_mode`: 0=OPEN_LOOP, 1=CURRENT, 2=SPEED, 3=POSITION
  - `enable`: Enable/disable motor
  - `clear_error`: Clear error flag
  - `set_zero`: Set current position as zero

### Publishers
- **`/whj_state`** ([`WhjState.msg`](./whj_can_interfaces/msg/WhjState.msg))
  - `position_deg`: Current position (degrees)
  - `speed_rpm`: Current speed (RPM)
  - `current_ma`: Current (mA)
  - `voltage_v`: Voltage (V)
  - `temperature_c`: Temperature (°C)
  - `error_code`: Error code (0 = no error)
  - `is_enabled`: Motor enabled status
  - `work_mode`: Current work mode

## 🚀 Usage

### 1. Standalone Launch

```bash
# Launch with default parameters
ros2 launch whj_can_py whj_can_py.launch.py

# Specify CAN interface
ros2 launch whj_can_py whj_can_py.launch.py can_interface:=can2

# Adjust trajectory planning (prevent errors on large moves)
ros2 launch whj_can_py whj_can_py.launch.py \
    can_interface:=can2 \
    motor_id:=7 \
    max_velocity:=800.0 \
    max_acceleration:=1500.0
```

### 2. Via S4 CLI

```bash
# Start complete system (includes WHJ)
./scripts/s4 dev

# Check status
ros2 topic echo /whj_state
```

### 3. Manual Control

```bash
# Enable motor
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, enable: true}'

# Move to target position (degrees) - auto trajectory planning
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, target_position_deg: 580.0}'

# Large distance move (>100°) - no error with trajectory planning!
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, target_position_deg: 400.0}'

# Clear error
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, clear_error: true}'

# Set zero position
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, set_zero: true}'
```

## ⚙️ Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `can_interface` | string | `can_fd` | CAN interface name |
| `motor_id` | int | 7 | Motor ID (1-30) |
| `state_publish_rate` | double | 10.0 | State publish frequency (Hz) |
| `auto_enable` | bool | true | Auto-enable on startup |
| `max_velocity` | double | 1000.0 | Trajectory max velocity [degrees/s] |
| `max_acceleration` | double | 2000.0 | Trajectory max acceleration [degrees/s²] |

**Trajectory Planning Recommendations**:
- Conservative: `max_velocity:=500.0, max_acceleration:=1000.0`
- Balanced: `max_velocity:=1000.0, max_acceleration:=2000.0` (default)
- Fast: `max_velocity:=2000.0, max_acceleration:=4000.0`

## 🔄 Trajectory Planning

**Problem**: Large position differences (>80°) cause motor errors.

**Solution**: Trapezoidal trajectory planning
- Decomposes large moves into smooth small steps
- Internal update rate: 100 Hz
- Configurable max velocity/acceleration
- Runs in background thread, non-blocking

## 🔧 Error Codes

Same as Kinco (16-bit bitmap):
- `0x0001`: FOC frequency too high
- `0x0002`: Over-voltage
- `0x0004`: Under-voltage
- `0x0008`: Over-temperature
- `0x0010`: Startup failed
- `0x0020`: Encoder error
- `0x0040`: Over-current
- See [full list](../../docs/can_id_discovery.md#error-codes)

## 📚 Python vs C++ Comparison

| Feature | Python (whj_can_py) | C++ (whj_can_control) |
|---------|---------------------|----------------------|
| Dependency | python-can | Native socket |
| CAN-FD Support | ✅ | ✅ |
| Trajectory Planning | ✅ | ❌ |
| Large Moves | ✅ No errors | ❌ May error |
| Debugging | Easy | Harder |
| Performance | Medium | High |

**Recommendation**: Use Python version for development and production.

## 📚 References

- [WHJ Protocol](./whj_can_py/whj_can_py/core/protocol/whj_protocol.py)
- [CAN Architecture](../../docs/can_design/can_architecture_comparison.md)
- [Main README](../../README.md)
- [← Back to Index](./README.md)

---

*Last Updated: 2026-04-01*
