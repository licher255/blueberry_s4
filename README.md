# Blueberry S4 - 移动操作机器人

[![ROS2](https://img.shields.io/badge/ROS2-Humble-blue)](https://docs.ros.org/en/humble/)
[![Python](https://img.shields.io/badge/Python-3.10-3776ab)](https://www.python.org/)
[![C++](https://img.shields.io/badge/C++-17-00599c)](https://isocpp.org/)

煜禾森 FW-Max AGV + RealMan WHJ 升降 + Kinco 旋转伺服 + 7× RealSense D405 + Livox Mid-360

---

## 🚀 30 秒快速开始

### 前提条件
- Ubuntu 22.04 (Jetson)
- ROS2 Humble 已安装
- CAN 硬件已连接

### 1. 克隆并编译

```bash
git clone https://github.com/licher255/blueberry_s4.git
cd blueberry_s4
source /opt/ros/humble/setup.bash
rm -rf build install log
colcon build --symlink-install
```

### 2. 初始化 CAN 设备（需要 sudo）

```bash
sudo ./scripts/s4 init
```

这会：
- 加载 CAN 内核模块
- 配置所有 CAN 接口（自动检测波特率）
- 建立设备映射（PEAK→AGV, ZLG→WHJ/Kinco）

### 3. 启动完整系统

```bash
./scripts/s4 dev
```

浏览器自动打开 `http://localhost:8080`，使用 WASD 控制 AGV，滑块控制 WHJ 升降和 Kinco 旋转。

**停止**: 按 `Ctrl+C`，会自动禁用电机使能。

---

## 📦 项目结构

```
blueberry_s4/
├── src/
│   ├── bringup/                    # 主启动包
│   │   ├── launch/robot.launch.py  # 系统启动入口
│   │   └── config/robot.yaml       # 全局参数
│   │
│   ├── YUHESEN-FW-MAX/             # ✅ AGV 驱动（第三方）
│   │   ├── yhs_can_control/        # C++ CAN 控制节点
│   │   └── yhs_can_interfaces/     # AGV 消息定义
│   │
│   ├── REALMAN-WHJ/                # ✅ WHJ 驱动（已完成）
│   │   ├── whj_can_py/             # Python 驱动（推荐使用）
│   │   │   ├── whj_can_py/whj_can_node.py      # ROS2 节点
│   │   │   ├── core/socketcan_driver.py        # SocketCAN 驱动
│   │   │   ├── core/zlgcan_driver.py           # ZLG CANFD 驱动
│   │   │   ├── core/protocol/whj_protocol.py   # WHJ 协议
│   │   │   └── drivers/whj_driver.py           # WHJ 电机控制
│   │   ├── whj_can_control/        # C++ 驱动（备用）
│   │   └── whj_can_interfaces/     # WHJ 消息定义
│   │
│   ├── KINCO/                      # ✅ Kinco 驱动（已完成）
│   │   ├── kinco_can_control/      # C++ CANopen 节点
│   │   │   └── src/kinco_can_control_node.cpp    # 主控制节点
│   │   └── kinco_can_interfaces/   # Kinco 消息定义
│   │
│   ├── hardware/                   # 硬件抽象层（预留）
│   ├── perception/                 # 感知算法（预留）
│   └── navigation/                 # 导航算法（预留）
│
├── scripts/
│   └── s4                           # 主控 CLI 工具
│
├── web_dashboard/
│   └── s4_dashboard.html            # Web 控制面板
│
└── drivers/
    └── peak-linux-driver-8.18.0/    # PEAK USB-CAN 驱动源码
```

---

## 🔌 硬件连接

### 设备清单

| 设备 | 型号 | 接口 | 状态 |
|------|------|------|------|
| AGV 底盘 | 煜禾森 FW-Max | PEAK USB-CAN | ✅ 已集成 |
| 升降机构 | RealMan WHJ | ZLG CANFD | ✅ 已集成 |
| 旋转电机 | Kinco FD1X5 | ZLG CANFD | ✅ 已集成 |
| 深度相机 | Intel D405×7 | USB 3.0 | ⏳ 预留 |
| 激光雷达 | Livox Mid-360 | 以太网 | ⏳ 预留 |

### 物理连接

```
Jetson
├── PEAK USB-CAN  →  煜禾森 FW-Max AGV (500K)
│                     CAN ID: 0x18C4xxxx
│
├── ZLG CANFD     →  RealMan WHJ (1M/5M CAN-FD)
│                     Node ID: 7
│                     ↓
└── (同一总线)     →  Kinco FD1X5 (1M/5M CAN-FD)
                      Node ID: 1
```

### 双 CAN 架构说明

**为什么需要两个 CAN 接口？**

| 接口 | 驱动 | 设备 | 波特率 | 原因 |
|------|------|------|--------|------|
| PEAK (can_agv) | pcan | AGV | 500K | AGV 只支持标准 CAN 500K |
| ZLG (can_fd) | usbcanfd | WHJ+Kinco | 1M/5M | WHJ/Kinco 需要 CAN-FD 高速通信 |

**波特率不兼容**：AGV 使用标准 CAN 500K，WHJ/Kinco 使用 CAN-FD 1M(仲裁段)/5M(数据段)，无法共用同一总线。

---

## 🛠️ S4 CLI 工具详解

### 完整命令列表

```bash
./scripts/s4 [command] [options]
```

| 命令 | 功能 | 示例 |
|------|------|------|
| `init` | 初始化 CAN 设备（需 sudo） | `sudo ./scripts/s4 init` |
| `build` | 编译工作空间 | `./scripts/s4 build` |
| `build clean` | 清理并编译 | `./scripts/s4 build clean` |
| `dev` | 启动开发环境 | `./scripts/s4 dev` |
| `dev sim` | 仿真模式 | `./scripts/s4 dev sim` |
| `dev teleop` | 硬件+键盘遥控 | `./scripts/s4 dev teleop` |
| `stop` | 停止所有节点 | `./scripts/s4 stop` |
| `status` | 查看系统状态 | `./scripts/s4 status` |
| `help` | 显示帮助 | `./scripts/s4 help` |

### 各命令详解

#### `s4 init` - 初始化硬件

```bash
sudo ./scripts/s4 init
```

执行流程：
1. 加载 CAN 内核模块 (`can`, `can_raw`, `can_dev`)
2. 加载 PEAK 和 ZLG 驱动 (`peak_usb`, `usbcanfd`)
3. 检测所有 CAN 接口并配置波特率
4. 建立设备映射文件 `/tmp/s4_can_mapping.conf`

输出示例：
```
✓ Module can loaded
✓ Module can_raw loaded
✓ can3 @ 500Kbps (pcan)        ← AGV (PEAK)
✓ can2 @ 1000Kbps (usbcanfd)    ← WHJ/Kinco (ZLG)
✓ can_agv (AGV)  -> can3
✓ can_fd (WHJ)   -> can2
```

#### `s4 build` - 编译项目

```bash
./scripts/s4 build              # 正常编译
./scripts/s4 build clean        # 清理后编译
./scripts/s4 build --packages-select bringup    # 只编译 bringup
```

自动执行：
1. 加载 ROS2 环境
2. 安装依赖 (`rosdep install`)
3. 编译 (`colcon build --symlink-install`)

#### `s4 dev` - 启动开发环境

```bash
./scripts/s4 dev        # 硬件模式（启动 AGV+WHJ+Kinco）
./scripts/s4 dev sim    # 仿真模式（无真实硬件）
./scripts/s4 dev teleop # 硬件+键盘遥控（需要显示器）
```

**硬件模式** (`dev`) 启动流程：
1. 读取 CAN 设备映射
2. 启动 Web 服务器 (端口 8080)
3. 启动 AGV 节点 (`ros2 launch bringup robot.launch.py`)
4. 启动 WHJ 节点 (`ros2 run whj_can_py whj_can_node`)
5. 启动 Kinco 节点 (`ros2 run kinco_can_control kinco_can_control_node`)
6. 启动 Rosbridge (端口 9091)
7. 打开浏览器

**停止** (`Ctrl+C`)：
1. 发送 CAN 帧禁用 WHJ (`007#020A0000`)
2. 发送 CAN 帧禁用 Kinco (`201#0106100000000000`)
3. 终止所有 ROS2 进程

#### `s4 status` - 查看状态

```bash
./scripts/s4 status
```

显示：
- CAN 接口状态和映射
- ROS2 节点运行状态
- 进程 PID

---

## 🎮 使用指南

### Web Dashboard 控制

启动后浏览器访问 `http://<jetson-ip>:8080`

**界面布局**：
```
┌─────────────────────────────────────────┐
│ 🔗 ROS2 连接 [连接/断开按钮]              │  ← 第1行：连接
├─────────────────────────────────────────┤
│ 🚗 AGV状态 │ 🛗 WHJ状态 │ ⚙️ Kinco状态 │  ← 第2行：状态
├─────────────────────────────────────────┤
│ AGV错误 │ WHJ错误 │ Kinco错误 [清除]    │  ← 第3行：错误
├─────────────────────────────────────────┤
│    🎮 AGV控制    │  🛗 WHJ控制         │  ← 第4行：控制
│  [方向键]        │  [滑块+按钮]         │
│  [紧急停止]      │  ⚙️ Kinco控制        │
│                  │  [滑块+预设角度]     │
└─────────────────────────────────────────┘
```

**操作步骤**：
1. 点击"连接"按钮连接 ROS2
2. AGV：按住 WASD 或方向键控制，松手停止
3. WHJ：拖动滑块设置目标位置（0-900mm），点击"移动"
4. Kinco：拖动滑块或点击预设角度（0°/90°/180°），点击"移动"

### 键盘遥控（teleop 模式）

```bash
./scripts/s4 dev teleop
```

按键映射：
| 按键 | 功能 |
|------|------|
| W / ↑ | 前进 |
| S / ↓ | 后退 |
| A / ← | 左转/左平移 |
| D / → | 右转/右平移 |
| Space | 紧急停止 |
| Q | 退出 |

**需要本地显示器**（不支持 SSH）。

---

## 🔧 故障排除

### 问题 1: CAN 设备未找到

```bash
# 检查 USB 设备
lsusb | grep -i "peak\|zlg"

# 手动加载驱动
sudo modprobe can can_raw can_dev peak_usb usbcanfd

# 重新初始化
sudo ./scripts/s4 init
```

### 问题 2: AGV 无法控制

```bash
# 检查 CAN 数据
candump can3

# 检查 ROS2 话题
ros2 topic echo /chassis_info_fb

# 手动发送测试命令
ros2 topic pub /ctrl_cmd yhs_can_interfaces/msg/CtrlCmd \
  '{ctrl_cmd_x_linear: 0.1, ctrl_cmd_gear: 6}'
```

### 问题 3: WHJ/Kinco 无响应

```bash
# 检查 CAN-FD 数据
candump can2

# 检查节点状态
ros2 node list | grep -i whj
ros2 topic echo /whj_state

# 手动使能 WHJ
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd \
  '{motor_id: 7, enable: true}'
```

### 问题 4: 编译失败

```bash
# 完全清理后编译
rm -rf build install log
source /opt/ros/humble/setup.bash
colcon build --symlink-install

# 检查依赖
rosdep install --from-paths src --ignore-src -y
```

---

## 📝 开发说明

### 添加新硬件驱动

在 `src/` 下创建新包：

```bash
cd src
ros2 pkg create my_hardware --build-type ament_python
cd ..
colcon build --packages-select my_hardware
```

### 修改现有驱动

**WHJ 驱动** (`src/REALMAN-WHJ/whj_can_py/`):
- 节点入口: `whj_can_py/whj_can_node.py`
- 协议定义: `core/protocol/whj_protocol.py`
- 电机控制: `drivers/whj_driver.py`

**Kinco 驱动** (`src/KINCO/kinco_can_control/`):
- 主节点: `src/kinco_can_control_node.cpp`
- 协议: CANopen (NMT, PDO, SDO)

**AGV 驱动** (`src/YUHESEN-FW-MAX/`):
- 第三方驱动，勿修改

---

## 📚 文档

- [PROJECT_LOG.md](./PROJECT_LOG.md) - 详细开发日志
- [AGENTS.md](./AGENTS.md) - AI 代理配置指南
- [docs/setup/](./docs/setup/) - 环境搭建指南
- [docs/hardware/](./docs/hardware/) - 硬件手册

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

*最后更新: 2026-04-01*
