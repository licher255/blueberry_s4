# WHJ CAN Python Driver

RealMan WHJ 升降机电机的 Python 驱动，基于 SocketCAN。

## 特点

- 使用 Linux SocketCAN（无需 ZLG 专有库）
- 支持 CAN-FD（1M/5M）
- **梯形轨迹规划** - 平滑运动，避免大距离移动报错
- 完整的 ROS2 接口

## 依赖

```bash
# 确保已安装 python-can
pip3 install python-can

# 确保 CAN 接口已配置
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on
```

## 使用方法

### 1. 构建包

```bash
cd ~/Blueberry_s4
source /opt/ros/humble/setup.bash
colcon build --packages-select whj_can_py --symlink-install
source install/setup.bash
```

### 2. 运行节点

```bash
# 使用 launch 文件（推荐）
ros2 launch whj_can_py whj_can_py.launch.py can_interface:=can2 motor_id:=7

# 调整轨迹规划参数（防止大距离移动报错）
ros2 launch whj_can_py whj_can_py.launch.py \
    can_interface:=can2 \
    motor_id:=7 \
    max_velocity:=800.0 \
    max_acceleration:=1500.0

# 或直接运行
ros2 run whj_can_py whj_can_node --ros-args \
    -p can_interface:=can2 \
    -p motor_id:=7 \
    -p max_velocity:=1000.0 \
    -p max_acceleration:=2000.0
```

### 3. 查看状态

```bash
# 监听状态
ros2 topic echo /whj_state

# 示例输出：
# position_deg: 395.6
# speed_rpm: 0.0
# current_ma: 1250.0
# voltage_v: 23.0
# temperature_c: 31.0
# error_code: 0
# is_enabled: true
# work_mode: 3  (POSITION_MODE)
```

### 4. 发送命令

```bash
# 移动到指定位置（单位：度）- 自动使用轨迹规划
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{
  motor_id: 7,
  target_position_deg: 580.0
}" --once

# 大距离移动（100°以上）也不会报错！
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{
  motor_id: 7,
  target_position_deg: 400.0
}" --once

# 清除错误
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{
  motor_id: 7,
  clear_error: true
}" --once

# 设置零点
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{
  motor_id: 7,
  set_zero: true
}" --once

# 禁用电机
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{
  motor_id: 7,
  enable: false
}" --once
```

### 5. 参数

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `can_interface` | `can_fd` | SocketCAN 接口名 |
| `motor_id` | `7` | 电机 ID (1-30) |
| `state_publish_rate` | `10.0` | 状态发布频率 (Hz) |
| `auto_enable` | `true` | 启动时自动使能电机并设为位置模式 |
| `max_velocity` | `1000.0` | 轨迹规划最大速度 [degrees/s] |
| `max_acceleration` | `2000.0` | 轨迹规划最大加速度 [degrees/s²] |

**轨迹规划参数建议**：
- 保守设置：`max_velocity:=500.0, max_acceleration:=1000.0`
- 平衡设置：`max_velocity:=1000.0, max_acceleration:=2000.0` (默认)
- 快速设置：`max_velocity:=2000.0, max_acceleration:=4000.0`

## 文件结构

```
whj_can_py/
├── whj_can_py/
│   ├── core/
│   │   ├── socketcan_driver.py  # SocketCAN 驱动（python-can）
│   │   └── protocol/            # 协议定义
│   ├── drivers/
│   │   └── whj_driver.py        # WHJ 电机驱动（含轨迹规划）
│   ├── whj_can_node.py          # ROS2 节点
│   └── __main__.py              # 模块入口
└── launch/
    └── whj_can_py.launch.py     # Launch 文件
```

## 与 C++ 版本对比

| 特性 | Python 版本 | C++ 版本 |
|------|------------|----------|
| 依赖 | python-can | 原生 socket |
| CAN-FD 支持 | ✅ | ✅ |
| 梯形轨迹规划 | ✅ | ❌ |
| 大距离移动 | ✅ 不报错 | ❌ 可能报错 |
| 调试 | 容易 | 较难 |
| 性能 | 中等 | 高 |

**建议**: 先用 Python 版本调试验证，再优化 C++ 版本。

## 已知问题与解决

### 1. 大距离移动报错 (已解决)
**问题**: 目标位置与当前位置差距 >80° 时，电机会报错

**解决**: 使用梯形轨迹规划，将大距离分解为平滑的小步进
- 内部更新率：100 Hz
- 最大速度/加速度可配置
- 在后台线程中执行，不阻塞 ROS 主循环

### 2. 消息类型 `whj_can_interfaces/msg/WhjState` 无效
**解决**: 确保已构建并 source 环境
```bash
colcon build --packages-select whj_can_interfaces whj_can_py
source install/setup.bash
```

### 3. `whj_cmd` 消息的 `work_mode` 字段
- 0 = OPEN_LOOP (默认，不设置)
- 1 = CURRENT_MODE
- 2 = SPEED_MODE  
- 3 = POSITION_MODE
