# Blueberry S4 - 移动操作机器人

[![ROS2](https://img.shields.io/badge/ROS2-Humble-blue)](https://docs.ros.org/en/humble/)
[![Python](https://img.shields.io/badge/Python-3.10-3776ab)](https://www.python.org/)
[![C++](https://img.shields.io/badge/C++-17-00599c)](https://isocpp.org/)

煜禾森 FW-Max AGV + RealMan WHJ 升降 + Kinco 伺服 + 7× RealSense D405 + Livox Mid-360

---

## 🚀 5 分钟快速开始

### 1. 克隆项目

```bash
git clone https://github.com/licher255/blueberry_s4.git
cd blueberry_s4
```

### 2. 编译项目

```bash
# 加载 ROS2 环境
source /opt/ros/humble/setup.bash

# 编译
rm -rf build install log
colcon build --symlink-install

# 加载编译后的环境
source install/setup.bash
```

### 3. 配置硬件（需要 sudo）

```bash
# 自动检测并配置 CAN 设备
sudo ./scripts/s4 init
```

### 4. 启动系统

```bash
# 方式 1: 一键启动（推荐）
./scripts/s4 dev

# 方式 2: 仿真模式（无硬件）
./scripts/s4 dev sim

# 方式 3: 硬件 + 键盘遥控
./scripts/s4 dev teleop
```

### 5. 打开 Web 控制面板

浏览器访问：`http://<jetson-ip>:8080`

---

## 🔌 硬件连接指南

### 硬件清单

| 设备 | 型号 | 接口 | CAN ID | 波特率 |
|------|------|------|--------|--------|
| **AGV 底盘** | 煜禾森 FW-Max | PEAK USB-CAN | 0x18C4xxxx | 500K |
| **升降机构** | RealMan WHJ | ZLG CANFD | Node 7 | 1M/5M |
| **旋转电机** | Kinco FD1X5 | ZLG CANFD | Node 1 | 1M/5M |
| **深度相机** | Intel D405×7 | USB 3.0 | - | - |
| **激光雷达** | Livox Mid-360 | 以太网 | - | - |

### 物理连接图

```
┌─────────────────────────────────────────────────────────────┐
│                      NVIDIA Jetson                          │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ PEAK USB-CAN │  │ ZLG CANFD    │  │ USB 3.0 Hub      │  │
│  │ (can_agv)    │  │ (can_fd)     │  │ (7× D405)        │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
└─────────┼─────────────────┼───────────────────┼────────────┘
          │                 │                   │
          ▼                 ▼                   ▼
┌─────────────────┐  ┌──────────────┐  ┌──────────────┐
│ 煜禾森 FW-Max   │  │ RealMan WHJ  │  │ Intel D405   │
│ AGV 底盘        │  │ 升降机构     │  │ 深度相机×7   │
└─────────────────┘  └──────┬───────┘  └──────────────┘
                            │
                     ┌──────┴──────┐
                     │ Kinco FD1X5 │
                     │ 旋转电机    │
                     └─────────────┘
```

### 连接步骤

#### 步骤 1: AGV 底盘连接（PEAK USB-CAN）

```
PEAK USB-CAN          Jetson CAN
────────────────────────────────────
CAN_H        →        CAN_H (can3)
CAN_L        →        CAN_L (can3)
GND          →        GND
```

**注意**: 确保 AGV 底盘的 120Ω 终端电阻已启用。

#### 步骤 2: WHJ + Kinco 连接（ZLG CANFD）

```
ZLG CANFD             WHJ + Kinco
────────────────────────────────────
CAN_H        →        CAN_H
CAN_L        →        CAN_L
GND          →        GND
```

**注意**: 
- WHJ (Node 7) 和 Kinco (Node 1) 共用同一 CAN 总线
- 确保只有一个 120Ω 终端电阻（通常在最后一个设备上）

#### 步骤 3: 相机连接

```
USB 3.0 Hub           Jetson USB 3.0
────────────────────────────────────
7× D405      →        USB 3.0 端口
```

---

## 🛠️ CAN 与 CAN FD 驱动逻辑

### 双 CAN 架构

S4 使用**双 CAN 架构**分离不同类型的设备：

| 总线 | 驱动 | 设备 | 协议 | 波特率 |
|------|------|------|------|--------|
| **can_agv** | pcan (PEAK) | AGV 底盘 | CAN 2.0 | 500K |
| **can_fd** | usbcanfd (ZLG) | WHJ + Kinco | CAN-FD | 1M (数据段 5M) |

### 为什么需要分离？

1. **波特率不同**: AGV 使用 500K，WHJ/Kinco 使用 1M/5M CAN-FD
2. **协议不同**: AGV 使用自定义协议，WHJ/Kinco 使用 CANopen
3. **稳定性**: 分离总线避免设备间的干扰

### 自动检测逻辑

`sudo ./scripts/s4 init` 会自动：

1. **检测 USB-CAN 设备**
   ```bash
   # PEAK USB-CAN (pcan 驱动)
   → 映射为 can_agv
   
   # ZLG CANFD (usbcanfd 驱动)
   → 映射为 can_fd
   ```

2. **配置接口参数**
   ```bash
   # AGV: 标准 CAN 500K
   ip link set can3 up type can bitrate 500000
   
   # WHJ/Kinco: CAN-FD 1M/5M
   ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on
   ```

3. **保存映射关系**
   ```bash
   cat /tmp/s4_can_mapping.conf
   # can_agv=can3
   # can_fd=can2
   ```

### 手动配置（如自动检测失败）

```bash
# 查看可用的 CAN 接口
ip link show type can

# 手动配置 AGV (假设是 can3)
sudo ip link set can3 up type can bitrate 500000

# 手动配置 WHJ/Kinco (假设是 can2)
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on
```

---

## 📐 项目架构

### 软件架构

```
┌─────────────────────────────────────────────────────────────┐
│                        应用层                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Web Dashboard│  │ Foxglove     │  │ RViz2            │  │
│  │ (浏览器)     │  │ (可视化)     │  │ (3D 可视化)      │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬─────────┘  │
└─────────┼─────────────────┼───────────────────┼────────────┘
          │                 │                   │
          └─────────────────┼───────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      ROS2 中间层                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ bringup (系统启动包)                                  │  │
│  │  ├─ robot.launch.py (主启动文件)                     │  │
│  │  ├─ config/robot.yaml (参数配置)                     │  │
│  │  └─ s4.rviz (RViz 配置)                              │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
┌─────────────────┐ ┌──────────────┐ ┌──────────────┐
│   AGV 驱动层    │ │  WHJ 驱动层   │ │ Kinco 驱动层 │
│ yhs_can_control │ │ whj_can_py   │ │ kinco_can_   │
│  (C++)          │ │ (Python)     │ │ control(C++) │
│  CAN ID: 0x18C4 │ │ CAN ID: 7    │ │ CAN ID: 1    │
└────────┬────────┘ └──────┬───────┘ └──────┬───────┘
         │                  │                │
         └──────────────────┼────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      硬件抽象层                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ PEAK PCAN    │  │ ZLG CANFD    │  │ SocketCAN        │  │
│  │ (USB-CAN)    │  │ (USB-CANFD)  │  │ (Linux 内核)     │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         ▼                  ▼                  ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 煜禾森 FW-Max│   │ RealMan WHJ  │   │ Kinco FD1X5  │
│ AGV 底盘     │   │ 升降机构     │   │ 旋转电机     │
└──────────────┘   └──────────────┘   └──────────────┘
```

### 代码目录结构

```
blueberry_s4/
├── src/
│   ├── bringup/                    # 主启动包
│   │   ├── launch/
│   │   │   └── robot.launch.py     # 系统启动入口
│   │   └── config/
│   │       └── robot.yaml          # 全局参数
│   │
│   ├── YUHESEN-FW-MAX/             # AGV 驱动 (第三方)
│   │   ├── yhs_can_control/        # C++ CAN 控制节点
│   │   └── yhs_can_interfaces/     # 消息定义
│   │
│   ├── REALMAN-WHJ/                # WHJ 驱动
│   │   ├── whj_can_py/             # Python 驱动 (推荐使用)
│   │   ├── whj_can_control/        # C++ 驱动 (备用)
│   │   └── whj_can_interfaces/     # 消息定义
│   │
│   └── KINCO/                      # Kinco 驱动
│       ├── kinco_can_control/      # C++ CANopen 节点
│       └── kinco_can_interfaces/   # 消息定义
│
├── scripts/
│   └── s4                           # 主控 CLI 工具
│
├── web_dashboard/                   # Web 控制面板
│   └── s4_dashboard.html
│
└── drivers/                         # CAN 驱动源码
    └── peak-linux-driver-8.18.0/    # PEAK 驱动
```

### 关键 ROS2 话题

| 话题 | 类型 | 说明 | 发布者 |
|------|------|------|--------|
| `/ctrl_cmd` | CtrlCmd | AGV 控制指令 | Dashboard/键盘 |
| `/chassis_info_fb` | ChassisInfoFb | AGV 状态反馈 | yhs_can_control |
| `/whj_cmd` | WhjCmd | WHJ 控制指令 | Dashboard |
| `/whj_state` | WhjState | WHJ 状态反馈 | whj_can_py |
| `/kinco_cmd` | KincoCmd | Kinco 控制指令 | Dashboard |
| `/kinco_state` | KincoState | Kinco 状态反馈 | kinco_can_control |

---

## 🎮 使用指南

### S4 CLI 工具

```bash
# 检查环境和依赖
./scripts/s4 check

# 编译项目
./scripts/s4 build

# 启动开发环境
./scripts/s4 dev          # 硬件模式
./scripts/s4 dev sim      # 仿真模式
./scripts/s4 dev teleop   # 硬件+键盘遥控

# 停止所有节点
./scripts/s4 stop

# 查看系统状态
./scripts/s4 status

# CAN 设备管理
sudo ./scripts/s4 can auto     # 自动配置 CAN
./scripts/s4 can status        # 查看 CAN 状态
```

### 手动启动（高级用户）

```bash
# 加载环境
source install/setup.bash

# 启动主系统
ros2 launch bringup robot.launch.py

# 指定 CAN 接口
ros2 launch bringup robot.launch.py can_agv_interface:=can3 can_devices_interface:=can2

# 仿真模式
ros2 launch bringup robot.launch.py sim:=true

# 禁用特定设备
ros2 launch bringup robot.launch.py use_agv:=false use_whj:=false
```

### Web Dashboard 控制

1. 启动系统后，浏览器访问 `http://<jetson-ip>:8080`
2. 点击"连接"按钮连接 ROS2
3. 使用 WASD 或方向键控制 AGV
4. 使用滑块控制 WHJ 升降和 Kinco 旋转

---

## 🐛 故障排除

### 问题 1: CAN 设备未找到

**症状**: `s4 status` 显示 "No CAN devices found"

**解决**:
```bash
# 检查 USB 设备是否识别
lsusb | grep -i "peak\|zlg"

# 手动加载驱动
sudo modprobe can can_raw can_dev peak_usb usbcanfd

# 重新配置
sudo ./scripts/s4 init
```

### 问题 2: AGV 无法控制

**症状**: Dashboard 连接成功但 AGV 不响应

**解决**:
```bash
# 检查 CAN 状态
candump can3 &

# 查看是否有数据
ros2 topic echo /chassis_info_fb

# 检查 AGV 是否解锁（需要发送解锁序列）
# Dashboard 连接时会自动发送
```

### 问题 3: WHJ/Kinco 无响应

**症状**: WHJ 或 Kinco 状态不更新

**解决**:
```bash
# 检查 CAN-FD 接口
candump can2 &

# 手动发送使能命令测试
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd '{motor_id: 7, enable: true}'
```

### 问题 4: 编译失败

**症状**: `colcon build` 报错

**解决**:
```bash
# 清理后重新编译
rm -rf build install log
colcon build --symlink-install

# 检查依赖
rosdep install --from-paths src --ignore-src -y
```

---

## 📚 文档

- [PROJECT_LOG.md](./PROJECT_LOG.md) - 详细开发日志
- [AGENTS.md](./AGENTS.md) - AI 代理配置指南
- [docs/setup/](./docs/setup/) - 环境搭建指南
- [docs/hardware/](./docs/hardware/) - 硬件手册

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 👥 贡献

欢迎提交 Issue 和 Pull Request！

---

*最后更新: 2026-04-01*
