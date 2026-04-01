# Kinco Servo Driver

[← Back to Index](./README.md) | [中文](./README_CN.md)

## Overview

This package provides ROS2 Humble driver for **Kinco FD1X5 Series Servo Motor**, using CANopen protocol over SocketCAN.

## 📁 Package Structure

```
KINCO/
├── kinco_can_control/              # Main C++ driver node
│   ├── src/kinco_can_control_node.cpp    # Source code
│   ├── include/kinco_can_control/
│   │   └── kinco_can_control_node.hpp    # Header file
│   ├── launch/kinco_can_control.launch.py  # Launch file
│   └── params/cfg.yaml              # Parameters
│
└── kinco_can_interfaces/           # ROS2 message definitions
    └── msg/
        ├── KincoCmd.msg             # Command message
        └── KincoState.msg           # State message
```

## 🔌 Hardware Connection

| Parameter | Value |
|-----------|-------|
| **Interface** | PEAK PCAN (shared with AGV) |
| **Bitrate** | 500Kbps (Standard CAN) |
| **Node ID** | 1 (default) |
| **Frame Type** | Standard 11-bit CAN frames |
| **Protocol** | CANopen CiA 301 |

**Note**: Kinco uses standard CAN frames (11-bit) while AGV uses extended frames (29-bit). They share the same physical bus without conflicts.

## 📡 CANopen Protocol

| Function | CAN ID | Description |
|----------|--------|-------------|
| **TPDO1** | `0x181` | Status Word + Warning Word (transmit) |
| **TPDO2** | `0x281` | Position + Velocity feedback (transmit) |
| **RPDO1** | `0x201` | Control Command (receive) |
| **RPDO2** | `0x301` | Position Target (receive) |
| **EMCY** | `0x081` | Emergency Messages (transmit) |
| **NMT** | `0x701` | Heartbeat (transmit) |

## 💬 ROS2 Topics

### Subscribers
- **`/kinco_cmd`** ([`KincoCmd.msg`](./kinco_can_interfaces/msg/KincoCmd.msg))
  - `node_id`: Servo node ID (default: 1)
  - `enable`: Enable/disable motor
  - `clear_error`: Clear error flag
  - `set_zero`: Set current position as zero
  - `target_position_deg`: Target position in degrees (0-180°)
  - `target_speed_rpm`: Target speed in RPM (default: 50)

### Publishers
- **`/kinco_state`** ([`KincoState.msg`](./kinco_can_interfaces/msg/KincoState.msg))
  - `position_deg`: Current position (degrees)
  - `speed_rpm`: Current speed (RPM)
  - `is_enabled`: Motor enabled status
  - `error_code`: Error code (0 = no error)
  - `target_reached`: True when position reached
  - `remaining_distance_deg`: Distance to target

## 🚀 Usage

### 1. Standalone Launch

```bash
# Launch with default parameters
ros2 launch kinco_can_control kinco_can_control.launch.py

# Specify CAN interface
ros2 launch kinco_can_control kinco_can_control.launch.py can_name:=can3

# Specify node ID
ros2 launch kinco_can_control kinco_can_control.launch.py node_id:=1
```

### 2. Via S4 CLI

```bash
# Start complete system (includes Kinco)
./scripts/s4 dev

# Check status
ros2 topic echo /kinco_state
```

### 3. Manual Control

```bash
# Enable motor
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, enable: true}'

# Move to 90 degrees
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, target_position_deg: 90.0, target_speed_rpm: 50.0}'

# Clear error
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, clear_error: true}'

# Set zero position
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, set_zero: true}'
```

## ⚙️ Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `can_name` | string | `can_fd` | CAN interface name |
| `node_id` | int | 1 | CANopen Node ID (1-127) |
| `state_publish_rate` | double | 10.0 | State publish frequency (Hz) |

## 🔧 Error Codes

| Error Code | Description |
|------------|-------------|
| `0x0001` | FOC frequency too high |
| `0x0002` | Over-voltage |
| `0x0004` | Under-voltage |
| `0x0008` | Over-temperature |
| `0x0010` | Startup failed |
| `0x0020` | Encoder error |
| `0x0040` | Over-current |
| `0x0080` | Software/hardware mismatch |
| `0x0100` | Temperature sensor error |
| `0x0200` | Position out of range |
| `0x0400` | Invalid motor ID |
| `0x0800` | Position tracking error |
| `0x1000` | Current sensor error |
| `0x2000` | Brake failed |
| `0x4000` | Position step too large (>10°) |
| `0x8000` | Multi-turn counter lost |

## 📚 References

- [Kinco FD1X5 Manual](../../docs/third%20party/Kinco%20FD1X5驱动器使用手册%2020250514.pdf)
- [CAN Architecture](../../docs/can_design/can_architecture_comparison.md)
- [Main README](../../README.md)
- [← Back to Index](./README.md)

---

*Last Updated: 2026-04-01*
