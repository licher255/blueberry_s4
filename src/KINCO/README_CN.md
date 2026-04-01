# Kinco 伺服驱动

[← 返回索引](./README.md) | [English](./README_EN.md)

## 概述

本软件包提供 **Kinco FD1X5 系列伺服电机** 的 ROS2 Humble 驱动，使用 CANopen 协议通过 SocketCAN 通信。

## 📁 软件包结构

```
KINCO/
├── kinco_can_control/              # 主 C++ 驱动节点
│   ├── src/kinco_can_control_node.cpp    # 源码
│   ├── include/kinco_can_control/
│   │   └── kinco_can_control_node.hpp    # 头文件
│   ├── launch/kinco_can_control.launch.py  # 启动文件
│   └── params/cfg.yaml              # 参数
│
└── kinco_can_interfaces/           # ROS2 消息定义
    └── msg/
        ├── KincoCmd.msg             # 命令消息
        └── KincoState.msg           # 状态消息
```

## 🔌 硬件连接

| 参数 | 值 |
|-----------|-------|
| **接口** | PEAK PCAN (与 AGV 共用) |
| **波特率** | 500Kbps (标准 CAN) |
| **节点 ID** | 1 (默认) |
| **帧类型** | 标准 11-bit CAN 帧 |
| **协议** | CANopen CiA 301 |

**注意**: Kinco 使用标准帧 (11-bit)，AGV 使用扩展帧 (29-bit)，两者可共用同一物理总线而不会冲突。

## 📡 CANopen 协议

| 功能 | CAN ID | 说明 |
|----------|--------|-------------|
| **TPDO1** | `0x181` | 状态字 + 告警字 (发送) |
| **TPDO2** | `0x281` | 位置 + 速度反馈 (发送) |
| **RPDO1** | `0x201` | 控制命令 (接收) |
| **RPDO2** | `0x301` | 位置目标 (接收) |
| **EMCY** | `0x081` | 紧急报文 (发送) |
| **NMT** | `0x701` | 心跳报文 (发送) |

## 💬 ROS2 话题

### 订阅
- **`/kinco_cmd`** ([`KincoCmd.msg`](./kinco_can_interfaces/msg/KincoCmd.msg))
  - `node_id`: 伺服节点 ID (默认: 1)
  - `enable`: 使能/禁用电机
  - `clear_error`: 清除错误标志
  - `set_zero`: 设置当前位置为零点
  - `target_position_deg`: 目标位置 (度，0-180°)
  - `target_speed_rpm`: 目标速度 (RPM，默认: 50)

### 发布
- **`/kinco_state`** ([`KincoState.msg`](./kinco_can_interfaces/msg/KincoState.msg))
  - `position_deg`: 当前位置 (度)
  - `speed_rpm`: 当前速度 (RPM)
  - `is_enabled`: 电机使能状态
  - `error_code`: 错误码 (0 = 无错误)
  - `target_reached`: 到达目标位置时为 true
  - `remaining_distance_deg`: 到目标的剩余距离

## 🚀 使用方法

### 1. 独立启动

```bash
# 使用默认参数启动
ros2 launch kinco_can_control kinco_can_control.launch.py

# 指定 CAN 接口
ros2 launch kinco_can_control kinco_can_control.launch.py can_name:=can3

# 指定节点 ID
ros2 launch kinco_can_control kinco_can_control.launch.py node_id:=1
```

### 2. 通过 S4 CLI 启动

```bash
# 启动完整系统（包含 Kinco）
./scripts/s4 dev

# 查看状态
ros2 topic echo /kinco_state
```

### 3. 手动控制

```bash
# 使能电机
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, enable: true}'

# 移动到 90 度
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, target_position_deg: 90.0, target_speed_rpm: 50.0}'

# 清除错误
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, clear_error: true}'

# 设置零点
ros2 topic pub /kinco_cmd kinco_can_interfaces/msg/KincoCmd \
  '{node_id: 1, set_zero: true}'
```

## ⚙️ 参数

| 参数 | 类型 | 默认值 | 说明 |
|-----------|------|---------|-------------|
| `can_name` | string | `can_fd` | CAN 接口名称 |
| `node_id` | int | 1 | CANopen 节点 ID (1-127) |
| `state_publish_rate` | double | 10.0 | 状态发布频率 (Hz) |

## 🔧 错误码

| 错误码 | 说明 |
|------------|-------------|
| `0x0001` | FOC 频率过高 |
| `0x0002` | 过压 |
| `0x0004` | 欠压 |
| `0x0008` | 过温 |
| `0x0010` | 启动失败 |
| `0x0020` | 编码器错误 |
| `0x0040` | 过流 |
| `0x0080` | 软件/硬件不匹配 |
| `0x0100` | 温度传感器错误 |
| `0x0200` | 位置超范围 |
| `0x0400` | 无效电机 ID |
| `0x0800` | 位置跟踪错误 |
| `0x1000` | 电流传感器错误 |
| `0x2000` | 刹车失败 |
| `0x4000` | 位置步进过大 (>10°) |
| `0x8000` | 多圈计数器丢失 |

## 📚 参考

- [Kinco FD1X5 手册](../../docs/third%20party/Kinco%20FD1X5驱动器使用手册%2020250514.pdf)
- [CAN 架构说明](../../docs/can_design/can_architecture_comparison.md)
- [主 README](../../README.md)
- [← 返回索引](./README.md)

---

*最后更新: 2026-04-01*
