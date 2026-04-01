# S4 - 移动操作机器人项目

[![ROS2](https://img.shields.io/badge/ROS2-Humble-blue)](https://docs.ros.org/en/humble/)
[![Python](https://img.shields.io/badge/Python-3.10-3776ab)](https://www.python.org/)

煜禾森 FW-Max AGV + RealMan 机械臂 + Kinco 伺服 + 多相机视觉系统

---

## 📁 项目结构

```
Blueberry_s4/                    # ⭐ ROS2 工作空间根目录
├── src/                         # 源代码目录
│   ├── bringup/                 # 启动配置包（主入口）
│   ├── description/             # 机器人模型描述
│   ├── hardware/                # 硬件抽象层
│   │   ├── yuhesen_fw_max/      # 煜禾森 AGV 驱动
│   │   ├── realman_whj/         # RealMan WHJ 升降
│   │   ├── kinco_servo/         # Kinco 伺服驱动
│   │   └── zlg_canfd/           # ZLG CAN-FD 接口
│   ├── perception/              # 感知算法
│   │   ├── d405_array/          # 7x D405 相机阵列
│   │   └── livox_lidar/         # Livox 激光雷达
│   ├── navigation/              # 导航算法
│   └── YUHESEN-FW-MAX/          # ⬇️ 第三方依赖
│       └── fw_max_robot/        # 原厂驱动（只读）
│
├── drivers/                     # 🆕 CAN 驱动源码
│   └── peak-linux-driver-8.18.0/# PEAK USB-CAN 驱动
│
├── scripts/                     # 实用脚本
│   ├── s4                       # 🆕 主控 CLI (check/dev/build/stop/status/can)
│   └── can_manager.sh           # 🆕 CAN 设备管理
│
├── web_dashboard/               # 🆕 Web 仪表盘
│   ├── index.html               # 监控页面
│   └── start_web_dashboard.sh   # 启动脚本
│
├── config/                      # 硬件配置文件
│   ├── hardware_profile.yaml    # 硬件参数
│   └── robots/                  # 不同机器人配置
│       ├── blueberry_s4.yaml    # 完整配置
│       └── blueberry_s4_minimal.yaml  # 最小配置
│
├── install/can_service/         # 🆕 CAN 服务配置
│   └── blueberry-can.service    # systemd 服务
│
├── docs/                        # 文档
│   ├── setup/                   # 环境搭建
│   ├── hardware/                # 硬件手册
│   └── api/                     # API 文档
│
├── build/                       # 编译输出（自动生成）
├── install/                     # 安装文件（自动生成）
├── log/                         # 日志（自动生成）
│
├── .gitignore
└── README.md                    # 本文件
```



## 🚀 快速开始

### ⚠️ Jetson 环境保护（重要！）

这台 Jetson 有其他同事的项目在运行，S4 项目使用**完全隔离**的部署方案。

#### 🚀 快速开始（1 步）

```bash
 ./scripts/start_agv_test.sh
```

#### 💻 Web Dashboard（浏览器查看）

启动 Web 仪表盘：

```bash
# 方式 1: 使用脚本
bash web_dashboard/start_web_dashboard.sh

# 方式 2: 手动启动
cd web_dashboard
python3 -m http.server 8080 &
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9091
```

然后在浏览器打开：`http://<jetson-ip>:8080`

支持的功能：
- 🎯 实时运动状态（速度、转向角、电压）
- 📡 ROS2 话题列表
- 📝 系统日志


#### 📋 常用命令

```bash
# 检查环境
./scripts/s4 check

# 启动
./scripts/s4 dev          # 硬件模式
./scripts/s4 dev sim      # 仿真模式
./scripts/s4 dev teleop   # 硬件+键盘遥控

# 停止
./scripts/s4 stop

# 查看状态
./scripts/s4 status

# CAN 管理
sudo ./scripts/s4 can auto     # 自动配置 CAN
./scripts/s4 can status        # 查看 CAN 状态
```

---

### 标准安装流程

#### 1. 安装 ROS2

```bash
# 安装 ROS2 Humble（如果还没有）
cd ~/Blueberry_s4
bash scripts/setup_ros2_env.sh
source ~/.bashrc
```

### 2. 配置硬件

```bash
# 查看硬件配置
cd ~/Blueberry_s4
python3 config/config_loader.py

# 生成 CAN 初始化脚本
python3 config/config_loader.py --script
sudo /tmp/setup_can.sh
```

### 3. 安装依赖

```bash
cd ~/Blueberry_s4

# 安装系统依赖
sudo apt update
sudo apt install -y \
    ros-humble-desktop \
    ros-humble-nav2-bringup \
    ros-humble-moveit \
    python3-can python3-serial

# 安装 ROS2 依赖
rosdep update
rosdep install --from-paths src --ignore-src -y
```

### 4. 编译

```bash
cd ~/Blueberry_s4

# 清理（如果需要）
rm -rf build install log

# 编译整个工作空间
colcon build --symlink-install

# 或只编译特定包
colcon build --packages-select bringup --symlink-install

# 加载环境
source install/setup.bash
```

### 5. 运行

#### 推荐方式 - 一键启动

```bash
# 一键启动（自动检查 CAN、编译、启动）
./scripts/s4 dev

# 模式选择
./scripts/s4 dev sim      # 仿真模式
./scripts/s4 dev teleop   # 硬件+键盘遥控
```

#### 手动启动

```bash
# 方式 1: 启动完整系统
ros2 launch bringup robot.launch.py

# 方式 2: 只启动 AGV
ros2 launch fw_max_bringup robot.launch.py

# 方式 3: 仿真模式（无真实硬件）
ros2 launch bringup robot.launch.py sim:=true

# 方式 4: 指定 CAN 接口 (使用物理接口名)
ros2 launch bringup robot.launch.py can_agv_interface:=can3 can_devices_interface:=can2
```

---

## 🔌 CAN 设备管理

S4 项目支持多种 CAN 设备，系统会自动检测和配置。

### 支持的 CAN 设备

| 设备类型 | 驱动 | 逻辑名 | 物理接口 | 说明 |
|---------|------|--------|----------|------|
| Jetson 内置 CAN | mttcan | - | can0/can1 | Jetson AGX Xavier 内置 |
| PEAK USB-CAN | pcan | **can_agv** | can2/can3 | AGV 底盘 (自动检测) |
| ZLG CANFD | usbcanfd | **can_fd** | can2/can3 | WHJ + Kinco (自动检测) |

> **注意**: USB-CAN 设备的物理接口名 (canX) 可能因启动顺序而变化，使用 `s4 init` 自动检测并映射到逻辑名。

### 快速命令

```bash
# 查看 CAN 设备状态
./scripts/s4 can status

# 自动检测并配置所有 CAN 设备
sudo ./scripts/s4 can auto

# 查看 CAN 设备映射
./scripts/s4 status

# 配置指定 CAN 接口 (如果需要手动配置)
sudo ip link set can3 up type can bitrate 500000  # AGV
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on  # WHJ

# 安装 PEAK USB-CAN 驱动（如需要）
sudo ./scripts/s4 can install-driver
```

### 开机自动配置



### 驱动本地化

PEAK USB-CAN 驱动源码已本地化：

```
drivers/
└── peak-linux-driver-8.18.0/     # PEAK 驱动源码
    ├── driver/                    # 内核模块源码
    ├── lib/                       # 库文件
    └── Makefile                   # 编译脚本
```

驱动会在首次检测到 PEAK 设备时自动编译安装。

---

## 🔧 硬件配置

### CAN 总线设置

编辑 `config/hardware_profile.yaml`：

```yaml
can_interfaces:
  - name: "can_agv"      # AGV: 煜禾森 FW-Max (PEAK PCAN-USB)
    device: "can_agv"    # 逻辑名，自动映射到实际 canX
    bitrate: 500000
    
  - name: "can_fd"       # 其他设备: WHJ + Kinco (ZLG CANFD)
    device: "can_fd"     # 逻辑名，自动映射到实际 canX
    bitrate: 1000000
    type: "canfd"
```

### 设备参数

```yaml
devices:
  agv:
    max_speed: 2.0        # m/s
    max_steering: 30.0    # 度
    
  whj_lifter:
    node_id: 7
    max_height: 0.5       # m
    
  kinco_servo:
    node_id: 1
    max_rpm: 3000
```

---

## 📦 包说明

### 核心包

| 包名 | 功能 | 状态 |
|------|------|------|
| `bringup` | 系统启动配置 | ✅ 已创建 |
| `description` | URDF 模型 | 📝 待创建 |
| `hardware` | 硬件抽象 | 📝 待创建 |

### 硬件驱动

| 包名 | 厂商 | 设备 | 协议 | 状态 |
|------|------|------|------|------|
| `yuhesen_fw_max` | 煜禾森 | FW-Max AGV | CAN 500K | ⬇️ 第三方 |
| `realman_whj` | RealMan | WHJ 升降 | CAN FD | 📝 待开发 |
| `kinco_servo` | Kinco | 伺服电机 | CANopen | 📝 待开发 |
| `zlg_canfd` | ZLG | CAN-FD 接口 | SocketCAN | 📝 待开发 |

### 感知

| 包名 | 设备 | 驱动 | 状态 |
|------|------|------|------|
| `d405_array` | 7x Intel D405 | realsense2_camera | 📝 待配置 |
| `livox_lidar` | Livox Mid-360 | livox_ros_driver2 | 📝 待配置 |

---

## 📝 开发工作流

### 添加新的硬件驱动

```bash
# 1. 创建包
cd ~/Blueberry_s4/src/blueberry_hardware
ros2 pkg create kinco_servo --build-type ament_python

# 2. 开发驱动代码
# ...

# 3. 编译
cd ~/Blueberry_s4
colcon build --packages-select kinco_servo --symlink-install

# 4. 测试
ros2 run kinco_servo servo_node
```

### 更新第三方依赖

```bash
cd ~/Blueberry_s4/src/YUHESEN-FW-MAX
git pull

cd ~/Blueberry_s4
colcon build --packages-select fw_max_msgs fw_max_can
```

---

## 🎮 常用命令

```bash
# ========== 编译 ==========
colcon build --symlink-install                    # 全编译
colcon build --packages-select <包名> --symlink-install  # 单包

# ========== 运行 ==========


# ========== 调试 ==========
ros2 topic list                    # 查看话题
ros2 topic echo /cmd_vel           # 监听速度指令
ros2 node info /agv_node           # 查看节点信息
rqt_graph                          # 可视化节点关系

# ========== 配置 ==========
ros2 param list                    # 列出参数
ros2 param get /agv_node max_speed # 获取参数
ros2 param set /agv_node max_speed 1.5  # 设置参数
```

---

## 📚 文档

### 入门指南
- [ROS2 环境搭建](./docs/ros2_setup/ros2_beginner_guide.md) - 从零开始安装 ROS2
- [主控脚本使用](./scripts/s4) - `./s4` 命令详解

### 硬件配置
- [硬件配置指南](./config/README.md) - CAN/设备参数配置
- [CAN 架构对比](./docs/can_design/can_architecture_comparison.md) - CAN 方案选型

### 可视化
- [Web Dashboard](./web_dashboard/README.md) - 浏览器监控仪表盘 ⭐
- [远程访问指南](./docs/deployment/remote_access_guide.md) - Foxglove/Web 远程连接

### 开发
- [系统架构设计](./docs/architecture_recommendation.md) - 整体技术方案
- [PROJECT_LOG.md](./PROJECT_LOG.md) - 开发日志

---

## 🤝 贡献指南

1. **Fork** 本项目
2. 创建 **Feature Branch** (`git checkout -b feature/amazing-feature`)
3. **Commit** 更改 (`git commit -m 'Add amazing feature'`)
4. **Push** 到分支 (`git push origin feature/amazing-feature`)
5. 创建 **Pull Request**

---

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE)

## 什么是对的开始
1. CAN 驱动加载
2. CAN2 pcan  -- can_agv
3. CAN3 usbcanfd -- can_fd
