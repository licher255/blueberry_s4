# RealMan WHJ 驱动

[← 返回索引](./README.md) | [English](./README_EN.md)

## 概述

**RealMan WHJ 升降电机** 的 ROS2 Humble 驱动，带梯形轨迹规划功能。

**主要特性**:
- 基于 SocketCAN（无需专有库）
- 支持 CAN-FD（1M/5M）
- **梯形轨迹规划** - 平滑运动，防止大距离移动报错
- 完整的 ROS2 接口

## 📁 软件包结构

```
REALMAN-WHJ/
├── whj_can_py/                     # Python 驱动（推荐使用）
│   ├── whj_can_py/
│   │   ├── core/
│   │   │   ├── socketcan_driver.py      # SocketCAN 驱动
│   │   │   └── protocol/whj_protocol.py # WHJ 协议
│   │   ├── drivers/whj_driver.py        # 带轨迹规划的电机驱动
│   │   ├── whj_can_node.py              # ROS2 节点
│   │   └── __main__.py                  # 模块入口
│   ├── launch/whj_can_py.launch.py      # 启动文件
│   └── README.md                        # 详细文档
│
├── whj_can_control/                # C++ 驱动（备用）
│   └── src/whj_can_control_node.cpp     # C++ 实现
│
└── whj_can_interfaces/             # ROS2 消息定义
    └── msg/
        ├── WhjCmd.msg                   # 命令消息
        └── WhjState.msg                 # 状态消息
```

**建议**: 使用 Python 驱动 (`whj_can_py`)，因为它具有轨迹规划功能。

## 🔌 硬件连接

| 参数 | 值 |
|-----------|-------|
| **接口** | ZLG CAN-FD（独立） |
| **波特率** | 1Mbps（仲裁段）/ 5Mbps（数据段） |
| **节点 ID** | 7（默认） |
| **帧类型** | CAN-FD |
| **协议** | RealMan 自定义协议 |

**注意**: WHJ 使用独立的 CAN-FD 总线，与 AGV/Kinco 分离，因为波特率要求不同。

## 📡 协议

| 功能 | CAN ID | 说明 |
|----------|--------|-------------|
| **读取** | `0x07` | 读取状态/位置 |
| **写入** | `0x07` | 写入命令 |
| **寄存器** | - | 0x0A（使能）、0x36/0x37（位置）、0x0F（清除错误） |

## 💬 ROS2 话题

### 订阅
- **`/whj_cmd`** ([`WhjCmd.msg`](./whj_can_interfaces/msg/WhjCmd.msg))
  - `motor_id`: 电机 ID（默认: 7）
  - `target_position_deg`: 目标位置（度，0-50000°）
  - `target_speed_rpm`: 目标速度（RPM）
  - `target_current_ma`: 目标电流（mA）
  - `work_mode`: 0=开环, 1=电流模式, 2=速度模式, 3=位置模式
  - `enable`: 使能/禁用电机
  - `clear_error`: 清除错误标志
  - `set_zero`: 设置当前位置为零点

### 发布
- **`/whj_state`** ([`WhjState.msg`](./whj_can_interfaces/msg/WhjState.msg))
  - `position_deg`: 当前位置（度）
  - `speed_rpm`: 当前速度（RPM）
  - `current_ma`: 电流（mA）
  - `voltage_v`: 电压（V）
  - `temperature_c`: 温度（°C）
  - `error_code`: 错误码（0 = 无错误）
  - `is_enabled`: 电机使能状态
  - `work_mode`: 当前工作模式

## 🚀 使用方法

### 1. 独立启动

```bash
# 使用默认参数启动
ros2 launch whj_can_py whj_can_py.launch.py

# 指定 CAN 接口
ros2 launch whj_can_py whj_can_py.launch.py can_interface:=can2

# 调整轨迹规划参数（防止大距离移动报错）
ros2 launch whj_can_py whj_can_py.launch.py \
    can_interface:=can2 \
    motor_id:=7 \
    max_velocity:=800.0 \
    max_acceleration:=1500.0
```

### 2. 通过 S4 CLI 启动

```bash
# 启动完整系统（包含 WHJ）
./scripts/s4 dev

# 查看状态
ros2 topic echo /whj_state
```

### 3. 手动控制

```bash
# 使能电机
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, enable: true}'

# 移动到目标位置（度）- 自动轨迹规划
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, target_position_deg: 580.0}'

# 大距离移动（>100°）- 有轨迹规划不会报错！
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, target_position_deg: 400.0}'

# 清除错误
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, clear_error: true}'

# 设置零点
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, set_zero: true}'
```

## ⚙️ 参数

| 参数 | 类型 | 默认值 | 说明 |
|-----------|------|---------|-------------|
| `can_interface` | string | `can_fd` | CAN 接口名称 |
| `motor_id` | int | 7 | 电机 ID（1-30） |
| `state_publish_rate` | double | 10.0 | 状态发布频率（Hz） |
| `auto_enable` | bool | true | 启动时自动使能 |
| `max_velocity` | double | 1000.0 | 轨迹规划最大速度 [度/s] |
| `max_acceleration` | double | 2000.0 | 轨迹规划最大加速度 [度/s²] |

**轨迹规划参数建议**:
- 保守设置：`max_velocity:=500.0, max_acceleration:=1000.0`
- 平衡设置：`max_velocity:=1000.0, max_acceleration:=2000.0`（默认）
- 快速设置：`max_velocity:=2000.0, max_acceleration:=4000.0`

## 🔄 梯形轨迹规划

**问题**: 位置差值较大（>80°）时，电机会报错。

**解决方案**: 梯形轨迹规划
- 将大距离分解为平滑的小步进
- 内部更新率：100 Hz
- 可配置最大速度/加速度
- 在后台线程中运行，不阻塞 ROS 主循环

## 🔧 错误码

与 Kinco 相同（16 位位图）:
- `0x0001`: FOC 频率过高
- `0x0002`: 过压
- `0x0004`: 欠压
- `0x0008`: 过温
- `0x0010`: 启动失败
- `0x0020`: 编码器错误
- `0x0040`: 过流
- 详见 [完整列表](../../docs/can_id_discovery.md#error-codes)

## 📚 Python vs C++ 对比

| 特性 | Python (whj_can_py) | C++ (whj_can_control) |
|---------|---------------------|----------------------|
| 依赖 | python-can | 原生 socket |
| CAN-FD 支持 | ✅ | ✅ |
| 轨迹规划 | ✅ | ❌ |
| 大距离移动 | ✅ 不报错 | ❌ 可能报错 |
| 调试 | 容易 | 较难 |
| 性能 | 中等 | 高 |

**建议**: 开发和生产都使用 Python 版本。

## 📚 参考

- [WHJ 协议](./whj_can_py/whj_can_py/core/protocol/whj_protocol.py)
- [CAN 架构说明](../../docs/can_design/can_architecture_comparison.md)
- [主 README](../../README.md)
- [← 返回索引](./README.md)

---

*最后更新: 2026-04-01*
