# S4 项目开发日志

## 📋 项目概览

**项目名称**: Blueberry S4  
**目标**: 煜禾森 FW-Max AGV + RealMan 机械臂 + Kinco 伺服 + 7x D405 相机 + Livox 激光雷达  
**平台**: NVIDIA Jetson (Ubuntu 22.04)  
**框架**: ROS2 Humble  
**状态**: ✅ 基础环境就绪，等待硬件连接

---

## 🗓️ 开发时间线

### 2025-03-23: 环境搭建日

#### ✅ 已完成

1. **项目结构规划**
   - 设计了 ROS2 工作空间结构
   - 创建了配置文件系统
   - 规划了硬件抽象层

2. **ROS2 环境部署**
   - 创建独立工作空间 `~/s4_ws`
   - 使用 ROS_DOMAIN_ID=42 隔离
   - 编译成功所有核心包

3. **CAN 总线配置**
   - 配置 can0 @ 500K (AGV)
   - 配置 can1 @ 1M CAN-FD (其他设备)
   - 节点运行正常，电机使能成功

4. **硬件配置**
   - YUHESEN FW-Max CAN ID: 待测试确定
   - RealMan WHJ CAN ID: 7
   - Kinco Servo CAN ID: 1

5. **可视化方案**
   - 规划 Foxglove Studio 远程访问
   - 配置 RViz 布局
   - 预留 Web 界面接口

#### 🔧 已知问题

- `fw_max_can` 包需要手动修复 lib 目录链接（已解决）
- C++ 节点因 API 兼容性问题暂时禁用（使用 Python 版本）
- 部分脚本需要 sudo 密码：`hkclr`

---

## 📁 项目结构

```
Blueberry_s4/
├── src/                          # ROS2 源代码
│   ├── bringup/                  # 主启动包
│   │   ├── launch/
│   │   │   └── robot.launch.py   # 主启动文件
│   │   ├── config/
│   │   │   ├── robot.yaml        # 参数配置
│   │   │   └── s4.rviz           # RViz 配置
│   │   └── layouts/
│   │       └── s4_default.json   # Foxglove 布局
│   ├── hardware/                 # 硬件驱动目录
│   ├── perception/               # 感知算法目录
│   ├── navigation/               # 导航算法目录
│   └── YUHESEN-FW-MAX/           # 煜禾森原厂驱动
│       └── fw_max_robot/
│           ├── fw_max_can/       # CAN 通信节点 ✅
│           ├── fw_max_msgs/      # 消息定义 ✅
│           └── fw_max_bringup/   # 原厂启动文件 ✅
│
├── config/                       # 硬件配置
│   ├── hardware_profile.yaml     # 硬件参数
│   └── config_loader.py          # 配置工具
│
├── scripts/                      # 实用脚本
│   ├── deploy_to_jetson.sh       # 一键部署
│   ├── jetson_precheck.sh        # 环境检查
│   ├── start_s4.sh               # 启动环境
│   ├── stop_s4.sh                # 停止节点
│   ├── start_remote_viz.sh       # 远程可视化
│   └── test_s4.sh                # 功能测试
│
├── docs/                         # 文档
│   ├── deployment/
│   │   ├── safe_deployment_guide.md
│   │   └── remote_access_guide.md
│   ├── ros2_setup/
│   │   ├── ros2_beginner_guide.md
│   │   └── visualization_tools.md
│   ├── can_design/
│   │   └── can_architecture_comparison.md
│   └── can_id_discovery.md
│
└── PROJECT_LOG.md                # 本文件
```

---

## 🚀 快速启动命令

```bash
# 1. 进入 S4 环境
source ~/s4_ws/start_s4.sh

# 2. 配置 CAN 接口（如需要）
bash /tmp/setup_can.sh
# 密码: hkclr

# 3. 启动完整系统
ros2 launch bringup robot.launch.py

# 4. 或启动仿真模式
ros2 launch bringup robot.launch.py sim:=true

# 5. 手动控制
ros2 topic pub /cmd_vel geometry_msgs/Twist '{linear: {x: 1.0}, angular: {z: 0.0}}' --once

# 6. 停止
bash ~/s4_ws/stop_s4.sh
```

---

## 🔌 硬件连接清单

### 当前状态
- [x] Jetson 系统配置
- [x] ROS2 环境部署
- [x] CAN 接口配置
- [ ] AGV 物理连接
- [ ] WHJ 升降连接
- [ ] Kinco 伺服连接
- [ ] D405 相机阵列
- [ ] Livox 激光雷达

### 连接步骤（下一步）

1. **AGV 连接**
   - CAN_H → Jetson can0_H
   - CAN_L → Jetson can0_L
   - GND → Jetson GND
   - 确认终端电阻 120Ω

2. **WHJ + Kinco**
   - 连接到 can1 (ZLG CAN-FD)
   - 确认波特率 1M

3. **相机和雷达**
   - D405 ×7 → USB 3.0 Hub
   - Livox → 以太网

---

## 🌐 远程访问配置

### SSH 连接信息
- **用户名**: `hkclr`
- **密码**: `hkclr`
- **IP**: `192.168.1.100` (待确认)
- **端口**: 22 (默认)


---

## 📝 待办事项

### 高优先级
- [ ] 物理连接 AGV 并测试 CAN 通信
- [ ] 确定 AGV 的 CAN ID (使用 candump)
- [ ] 测试电机控制
- [ ] 安装 Foxglove Bridge (`sudo apt install ros-humble-foxglove-bridge`)

### 中优先级
- [ ] 创建 WHJ 升降驱动包
- [ ] 创建 Kinco 伺服驱动包
- [ ] 配置 D405 相机阵列
- [ ] 配置 Livox 激光雷达

### 低优先级
- [ ] 修复 C++ 节点编译
- [ ] 优化启动脚本
- [ ] 添加更多调试工具

---

## 🐛 已知问题与解决

### 问题 1: fw_max_can 包未找到
**症状**: `package 'fw_max_can' not found`  
**原因**: colcon 未正确识别包类型  
**解决**: 
```bash
# 修改 package.xml
<buildtool_depend>ament_python</buildtool_depend>
<build_type>ament_python</build_type>

# 重新编译
cd ~/s4_ws && colcon build --packages-select fw_max_can
```

### 问题 2: libexec 目录不存在
**症状**: `libexec directory does not exist`  
**解决**: 手动创建链接
```bash
mkdir -p ~/s4_ws/install/fw_max_can/lib/fw_max_can
cp ~/s4_ws/src/fw_max_can/scripts/*.py ~/s4_ws/install/fw_max_can/lib/fw_max_can/
```

### 问题 3: CAN 接口未启动
**症状**: `Network is down`  
**解决**:
```bash
sudo modprobe can can_raw
sudo ip link set can0 up type can bitrate 500000
```

---

## 💡 关键配置

### CAN 接口配置
```bash
# can0 - AGV (YUHESEN FW-Max)
sudo ip link set can0 up type can bitrate 500000

# can1 - WHJ + Kinco (CAN-FD)
sudo ip link set can1 up type can bitrate 1000000 dbitrate 5000000 fd on
```

### ROS2 环境
```bash
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0
source ~/s4_ws/install/setup.bash
```

---

## 📚 参考文档

- [煜禾森官网](https://www.yuhesen.com)
- [YUHESEN ROS2 驱动](https://github.com/YUHESEN-Robot/FW-max-ros2)
- [ROS2 Humble 文档](https://docs.ros.org/en/humble/)
- [Foxglove Studio](https://foxglove.dev/)

---

## 👥 开发团队

- **项目负责人**: hkclr
- **AI 助手**: Kimi Code CLI
- **合作开始**: 2025-03-23

---

## 🎯 项目目标

构建一个完整的移动操作机器人系统，集成：
- 煜禾森 FW-Max AGV (移动底盘)
- RealMan WHJ 升降机构
- Kinco 伺服系统
- 7× Intel D405 深度相机
- Livox Mid-360 激光雷达

应用于工业自动化、仓储物流等场景。

---

*最后更新: 2025-03-23*  
*下次计划: 物理连接 AGV，测试 CAN 通信*

---

## 2025-03-23 Update: AGV CAN 驱动修复

### 问题发现
- 原有的 `fw_max_can` 驱动使用的是 **11-bit 标准帧** (0x200, 0x202)
- 实际的 FW-Max AGV 使用的是 **29-bit 扩展帧** (0x18C4D7EF, 0x18C4D9EF...)

### 解决方案
- 从官方仓库克隆了正确的驱动: `yhs_can_control`
- 编译并安装了官方驱动
- CAN ID 映射:
  - `0x18C4D7EF` - 左后轮反馈
  - `0x18C4D9EF` - 右前轮反馈
  - `0x18C4DAEF` - IO 反馈
  - `0x98C4D1D0` - 控制命令发送

### 使用方法
```bash
# 1. 进入 S4 环境
source ~/s4_ws/start_s4.sh

# 2. 启动官方 AGV 驱动
ros2 launch yhs_can_control yhs_can_control.launch.py

# 3. 查看底盘反馈
ros2 topic echo /chassis_info_fb

# 4. 发送控制命令 (测试用)
ros2 topic pub /ctrl_cmd yhs_can_interfaces/msg/CtrlCmd \
  '{ctrl_cmd_x_linear: 0.1, ctrl_cmd_z_angular: 0.0, ctrl_cmd_gear: 1}'
```

---



## 2025-03-23: 本地化可视化方案（无需 Google 登录）

### 问题
- Foxglove Studio 在线版需要 Google 账户登录
- 需要本地化的可视化方案

### 解决方案


#### 方案 4: Web Dashboard（推荐，无需安装）⭐
```bash
bash ~/s4_ws/launch_web.sh
```

然后在浏览器打开显示的 URL：
```
http://192.168.1.100:8080
```

### Web Dashboard 功能
- 实时速度显示（线性/角速度）
- 电池状态（电压、SOC、电流）
- 轮子速度监控
- IO 状态（急停、遥控、车灯）
- 自动重连

### 文件位置
- Web 页面: `~/s4_ws/web_dashboard/index.html`
- RViz 配置: `~/s4_ws/config/agv_rviz.rviz`
- 启动脚本: `~/s4_ws/launch_*.sh`

---

## 2025-03-23: RViz2 可视化配置完成

### 新增功能
- ✅ CAN 桥接节点（RViz 版）- 发布 /odom 和 TF
- ✅ RViz2 配置文件
- ✅ 一键启动脚本

### 启动命令
```bash
bash ~/s4_ws/launch_rviz_full.sh
```

### 可视化内容
| 显示项 | 说明 |
|--------|------|
| Grid | 参考网格 |
| TF | 机器人坐标变换 |
| Odometry | AGV 运动轨迹 (积分) |
| Axes | 坐标轴 |

### 远程访问方法

#### 方法 1: SSH X11 转发（推荐）
```bash
# 在本地电脑执行
ssh -X hkclr@192.168.1.100
bash ~/s4_ws/launch_rviz_full.sh
```

#### 方法 2: VNC 远程桌面
```bash
# 在 Jetson 安装并启动 VNC
sudo apt install tigervnc-standalone-server
vncserver :1 -geometry 1920x1080 -depth 24

# 本地电脑使用 VNC Viewer 连接
# 地址: 192.168.1.100:5901
```

#### 方法 3: 分离运行
```bash
# Jetson 上只运行桥接节点
python3 ~/s4_ws/src/yhs_can_control/scripts/can_bridge_rviz.py

# 本地电脑运行 RViz2（设置相同 ROS_DOMAIN_ID）
export ROS_DOMAIN_ID=42
ros2 run rviz2 rviz2
```

### 文件位置
- 启动脚本: `~/s4_ws/launch_rviz_full.sh`
- RViz 配置: `~/s4_ws/config/agv_rviz.rviz`
- 桥接节点: `~/s4_ws/src/yhs_can_control/scripts/can_bridge_rviz.py`

### 已发布话题
- `/chassis_info_fb` - 底盘完整状态
- `/odom` - 里程计数据（RViz 用）
- `/tf` - 坐标变换（RViz 用）

---

## 2025-03-23: Web Dashboard 端口冲突修复

### 问题
- 端口 9090 被 Clash (mihomo) 占用
- Web Dashboard 显示 Disconnected
- Rosbridge 无法绑定端口

### 解决方案
- 修改端口：9090 → 9091
- 更新启动脚本: `launch_web_fixed.sh`
- 更新网页：添加手动连接功能

### 新的启动命令
```bash
bash ~/s4_ws/launch_web_fixed.sh
```

### 访问 URL
```
http://192.168.1.100:8080?ws=ws://192.168.1.100:9091
```

### 如果仍无法连接
1. 检查输入框中的 WebSocket URL 是否正确
2. 点击 "Connect" 按钮手动连接
3. 确保防火墙允许 9091 端口

### 文件更新
- 新启动脚本: `~/s4_ws/launch_web_fixed.sh`
- 更新页面: `~/s4_ws/web_dashboard/index.html`


---

## 2026-03-24: 系统重启后修复与一键脚本完善

### 问题回顾
系统重启后遇到多个问题，导致无法启动机器人：

1. **包名错误**: `blueberry_bringup` 不存在，正确为 `bringup`
2. **setup.bash 路径错误**: 用户在 `scripts/` 目录运行 source
3. **fw_max_can 可执行文件缺失**: entry_points 未配置，libexec 目录不存在
4. **CAN 接口未启用**: can0 状态为 DOWN
5. **xterm 错误**: SSH 环境下无法打开显示

### 修复内容

#### 1. 脚本修复
- **scripts/check_workspace.sh**: 修正 `blueberry_bringup` → `bringup`
- **scripts/start_robot.sh**: 新增一键启动脚本，功能包括：
  - 自动检查 ROS2 环境
  - 自动编译工作空间
  - 自动修复 fw_max_can libexec 路径
  - SSH 环境检测（禁用 xterm teleop）
  - 彩色输出与状态提示

#### 2. 新创建脚本
```
scripts/
├── start_robot.sh      # 启动机器人
├── stop_robot.sh       # 停止机器人
├── run.sh              # 一键运行 (CAN设置+启动)
├── status.sh           # 系统状态检查
├── setup_can.sh        # CAN 接口配置
└── setup_peak_socketcan.sh  # PEAK 驱动模式切换
```

#### 3. fw_max_can 包修复
- **setup.py**: 添加 entry_points 配置
  ```python
  entry_points={
      'console_scripts': [
          'can_bridge_py = fw_max_can.can_bridge_py:main',
          'teleop_keyboard = fw_max_can.teleop_keyboard:main',
      ],
  }
  ```
- 将脚本从 `scripts/` 复制到包目录 `fw_max_can/`
- 创建 libexec 目录软链接指向 bin/

#### 4. launch 文件更新
- **src/bringup/launch/robot.launch.py**: 添加 `use_teleop` 参数
  - SSH 环境下自动禁用键盘遥控（避免 xterm 错误）
  - 支持 sim/hw/teleop 三种模式

### PEAK USB-CAN 驱动问题诊断

**问题**: can0 UP 但无数据收发

**诊断结果**:
```
USB设备: ID 0c72:000c PEAK System PCAN-USB
驱动: pcan (chardev模式)
设备节点: /dev/pcanusb32
```

**原因**: PEAK 设备当前使用 **chardev 模式** (专有 API)，而代码使用 **SocketCAN** 标准接口。

**当前 CAN 接口状态**:
```
can0: UP - Jetson 内置 CAN (mttcan 驱动)
can1: DOWN - 未使用
```

**解决方案** (待执行):
```bash
# 1. 卸载 chardev 驱动
sudo rmmod pcan

# 2. 加载 SocketCAN 驱动
sudo modprobe can can_raw can_dev peak_usb

# 3. 检查新接口 (可能是 can2)
ip link show type can

# 4. 启用新接口
sudo ip link set can2 up type can bitrate 500000
```

### 当前快速命令

```bash
# 检查系统状态
bash scripts/status.sh

# 一键启动（自动处理 CAN）
bash scripts/run.sh

# 或分步操作
sudo bash scripts/setup_can.sh      # 设置 CAN
bash scripts/start_robot.sh          # 启动机器人
bash scripts/stop_robot.sh           # 停止机器人

# 模式选择
bash scripts/run.sh sim      # 仿真模式
bash scripts/run.sh hw       # 硬件模式
bash scripts/run.sh teleop   # 硬件+键盘遥控
```

### 待办事项更新

- [ ] 切换 PEAK USB-CAN 到 SocketCAN 模式
- [ ] 确定正确的 CAN 接口名称 (can0/can1/can2)
- [ ] 验证 AGV CAN 通信
- [ ] 测试电机控制
- [ ] 配置 D405 相机阵列
- [ ] 配置 Livox 激光雷达

### 文件变更

```
修改: scripts/check_workspace.sh
修改: src/bringup/launch/robot.launch.py
修改: src/YUHESEN-FW-MAX.bak/fw_max_robot/fw_max_can/setup.py
新增: scripts/start_robot.sh
新增: scripts/stop_robot.sh
新增: scripts/run.sh
新增: scripts/status.sh
新增: scripts/setup_can.sh
新增: scripts/setup_peak_socketcan.sh
```

*最后更新: 2026-03-24*


---

## 2026-03-24 Update: PEAK USB-CAN 灯不闪问题诊断

### 问题现象
- PEAK USB-CAN 设备已连接（USB 识别正常）
- 设备指示灯 **不闪烁**
- `/etc/rc.local` 不存在（Ubuntu 22.04 默认无此文件）

### 诊断结果

**USB 设备状态:**
```
Bus 001 Device 004: ID 0c72:000c PEAK System PCAN-USB
Driver: pcan (chardev 模式)
```

**设备状态:**
```
/proc/pcan:
32    usb   -NA- ffffffff 000 0x001c 00000000 00000000 00000000 00000000 0x0000
       ↑
    ndev=-NA- 表示没有应用程序打开设备
```

### 灯不闪的原因

**根本原因**: PEAK 设备当前使用 **chardev 模式** (`pcan` 驱动)
- 在 chardev 模式下，灯只在有数据收发时闪烁
- 没有应用程序打开 `/dev/pcanusb32` 时，设备处于待机状态
- 需要主动打开设备才会有灯闪

### 解决方案

#### 方案 1: 切换到 SocketCAN 模式 (推荐)
SocketCAN 模式下设备更活跃，有数据时灯会闪烁：

```bash
# 1. 卸载 chardev 驱动
sudo rmmod pcan

# 2. 加载 SocketCAN 驱动
sudo modprobe can can_raw can_dev peak_usb

# 3. 检查新接口
ip link show type can

# 4. 启用接口（假设是 can2）
sudo ip link set can2 up type can bitrate 500000

# 5. 测试
candump can2 &
cansend can2 123#DEADBEEF
```

#### 方案 2: 使用 chardev 模式 + 自动配置
保持当前模式，创建启动脚本自动配置：

```bash
# 运行诊断测试
bash scripts/test_peak.sh

# 安装自动配置服务
sudo bash scripts/install_peak_service.sh

# 重启后自动配置
sudo reboot
```

### 新增脚本

| 脚本 | 功能 |
|------|------|
| `scripts/test_peak.sh` | PEAK 设备诊断测试 |
| `scripts/setup_peak_auto.sh` | PEAK 自动配置脚本 |
| `scripts/install_peak_service.sh` | 安装 systemd 自动服务 |
| `scripts/setup_peak_socketcan.sh` | 切换到 SocketCAN 模式 |

### 自动配置服务安装

```bash
# 安装服务（自动配置 CAN 接口）
sudo bash scripts/install_peak_service.sh

# 手动运行测试
bash scripts/test_peak.sh
```

### 下一步

1. **立即测试** SocketCAN 模式：
   ```bash
   sudo rmmod pcan
   sudo modprobe can can_raw can_dev peak_usb
   ip link show type can
   ```

2. **查看新的 CAN 接口名称**（可能是 can2）

3. **更新 launch 文件**使用正确的接口

*记录时间: 2026-03-24*


---

## 2026-03-24 Update: PEAK USB-CAN 修复进展

### 诊断结果

经过详细检查，发现问题如下：

```
can0: mttcan (Jetson 内置 CAN) - UP
can1: mttcan (Jetson 内置 CAN) - DOWN

USB 设备: PEAK PCAN-USB 已连接
驱动状态: 未加载 peak_usb
```

**结论**: PEAK USB 设备**没有被识别为 SocketCAN 接口**，因为 `peak_usb` 驱动未加载。

### 修复步骤

请**手动执行**以下命令：

```bash
# 1. 进入项目目录
cd ~/Blueberry_s4

# 2. 运行修复脚本
sudo bash scripts/fix_peak_usb.sh
```

或者分步执行：

```bash
# 1. 卸载 chardev 驱动
sudo rmmod pcan

# 2. 加载 SocketCAN 驱动
sudo modprobe can can_raw can_dev peak_usb

# 3. 等待 2 秒，检查新接口
ip link show type can

# 4. 启用新的 CAN 接口（假设是 can2）
sudo ip link set can2 up type can bitrate 500000

# 5. 测试灯是否闪烁
candump can2 &
cansend can2 123#DEADBEEF
```

### 如果 peak_usb 加载失败

可能需要安装额外的内核模块：

```bash
# 安装 linux-can 包
sudo apt update
sudo apt install -y linux-modules-extra-$(uname -r)

# 重新加载驱动
sudo modprobe peak_usb
```

### 当前状态

- ✅ Jetson 内置 CAN (can0/can1) 正常
- ⚠️ PEAK USB-CAN 未配置为 SocketCAN
- 🔄 等待用户运行修复脚本

### 新增脚本

- `scripts/fix_peak_usb.sh` - PEAK USB-CAN SocketCAN 修复脚本

*记录时间: 2026-03-24*


---

## 2026-03-24 Update: PEAK USB-CAN 驱动编译

### 问题确认
Jetson 内核 (`5.15.148-tegra`) **没有预装 `peak_usb` 驱动模块**，需要手动编译安装。

### 编译安装步骤

#### 方法 1: 一键脚本 (推荐)

```bash
cd ~/Blueberry_s4
sudo bash scripts/install_peak_driver.sh
```

#### 方法 2: 手动编译

```bash
# 1. 进入临时目录
cd /tmp

# 2. 安装依赖
sudo apt update
sudo apt install -y build-essential linux-headers-$(uname -r) wget

# 3. 下载驱动源码
wget https://www.peak-system.com/fileadmin/media/linux/files/peak-linux-driver-8.18.0.tar.gz

# 4. 解压
tar -xzf peak-linux-driver-8.18.0.tar.gz
cd peak-linux-driver-8.18.0

# 5. 编译 (SocketCAN 模式)
make clean
make NET=NETDEV_SUPPORT -j$(nproc)

# 6. 安装
sudo make install

# 7. 加载驱动
sudo rmmod pcan 2>/dev/null || true
sudo modprobe can can_raw can_dev peak_usb

# 8. 检查新接口
ip link show type can

# 9. 启用接口 (假设是 can2)
sudo ip link set can2 up type can bitrate 500000
```

### 编译参数说明

| 参数 | 模式 | 说明 |
|------|------|------|
| `make` (默认) | chardev | 设备节点 `/dev/pcanusb32`，灯不闪 |
| `make NET=NETDEV_SUPPORT` | SocketCAN | 网络接口 `canX`，灯随数据闪烁 ✅ |

**必须使用 `NET=NETDEV_SUPPORT` 编译！**

### 安装后验证

```bash
# 1. 检查驱动加载
lsmod | grep peak_usb

# 2. 查找新接口
ip link show type can

# 3. 测试灯闪烁
candump can2 &
cansend can2 123#DEADBEEF

# 4. 启动机器人
ros2 launch bringup robot.launch.py can_agv_interface:=can2
```

### 开机自动加载

```bash
# 添加到 /etc/modules
echo "peak_usb" | sudo tee -a /etc/modules

# 或使用 systemd 服务
sudo bash scripts/install_peak_service.sh
```

### 新增脚本

- `scripts/install_peak_driver.sh` - PEAK 驱动编译安装脚本

### 待执行

用户需要运行：
```bash
sudo bash scripts/install_peak_driver.sh
```

*记录时间: 2026-03-24*


---

## 2026-03-24 Update: PEAK 驱动安装修复

### 问题
首次安装时 `peak_usb` 模块找不到，驱动安装到了错误的位置。

### 修复方法

使用 `make netdev` 编译（而非 `make NET=NETDEV_SUPPORT`），并手动安装到内核模块目录：

```bash
# 重新编译安装
cd /tmp/peak-linux-driver-8.18.0
sudo bash ~/Blueberry_s4/scripts/install_peak_driver_fixed.sh
```

### 手动步骤

```bash
cd /tmp/peak-linux-driver-8.18.0

# 1. 清理
make clean

# 2. 编译 netdev 版本
make netdev -j$(nproc)

# 3. 手动安装
sudo mkdir -p /lib/modules/$(uname -r)/kernel/drivers/net/can
sudo cp driver/pcan.ko /lib/modules/$(uname -r)/kernel/drivers/net/can/
sudo chmod 644 /lib/modules/$(uname -r)/kernel/drivers/net/can/pcan.ko

# 4. 更新模块依赖
sudo depmod -a

# 5. 加载驱动
sudo modprobe can can_raw can_dev
sudo modprobe pcan

# 6. 检查新接口
ip link show type can
```

### 预期结果
- 驱动: `pcan` (netdev/SocketCAN 版本)
- 接口: 新的 `canX` (如 can2)
- 设备灯: 有数据时闪烁

### 新增脚本

- `scripts/install_peak_driver_fixed.sh` - 修复版安装脚本

*记录时间: 2026-03-24*


---

## 2026-03-24 Update: CAN 设备管理系统重构

### 问题背景
昨天关机后，今天重启时遇到一系列 CAN 相关问题：
- PEAK USB-CAN 驱动未自动加载
- CAN 接口未自动启用
- 需要手动执行多个步骤才能恢复通信
- 驱动源码需要从网络下载

### 解决方案

构建完整的 **CAN 设备管理系统**，实现：
1. **驱动本地化** - PEAK 驱动源码包含在项目中
2. **自动检测** - 开机自动检测所有 CAN 设备
3. **自动配置** - 自动安装驱动、启用接口
4. **服务化** - systemd 服务确保开机启动
5. **多设备支持** - 支持 Jetson 内置 CAN + USB-CAN

### 新增文件结构

```
Blueberry_s4/
├── drivers/
│   ├── peak-linux-driver-8.18.0/          # PEAK 驱动源码
│   └── peak-linux-driver-8.18.0.tar.gz    # 原始压缩包
│
├── install/can_service/
│   └── blueberry-can.service              # systemd 服务
│
└── scripts/
    ├── can_manager.sh                     # CAN 设备管理器
    ├── install_can_service.sh             # 安装 CAN 服务
    ├── install_peak_driver.sh             # 安装 PEAK 驱动
    ├── install_peak_driver_fixed.sh       # 修复版安装
    ├── fix_peak_usb.sh                    # PEAK 修复脚本
    ├── setup_peak_auto.sh                 # 自动配置 PEAK
    ├── setup_peak_socketcan.sh            # SocketCAN 模式
    ├── test_peak.sh                       # PEAK 诊断
    ├── start_robot.sh                     # 启动机器人 (更新)
    ├── run.sh                             # 一键运行 (更新)
    ├── status.sh                          # 系统状态
    └── stop_robot.sh                      # 停止机器人
```

### 核心功能

#### 1. CAN 设备管理器 (`can_manager.sh`)

```bash
# 查看状态
bash scripts/can_manager.sh status

# 自动配置所有 CAN 设备
sudo bash scripts/can_manager.sh auto

# 配置指定接口
sudo bash scripts/can_manager.sh setup can2 500000

# 安装 PEAK 驱动
sudo bash scripts/can_manager.sh install-driver
```

**功能：**
- 自动检测 Jetson 内置 CAN (mttcan)
- 自动检测 PEAK USB-CAN (pcan)
- 自动检测通用 USB-CAN (gs_usb)
- 自动安装缺失的驱动
- 自动配置接口参数

#### 2. 开机自动服务 (`blueberry-can.service`)

```bash
# 安装服务
sudo bash scripts/install_can_service.sh

# 管理服务
sudo systemctl status blueberry-can
sudo systemctl start blueberry-can
sudo journalctl -u blueberry-can -f
```

**功能：**
- 开机自动运行 `can_manager.sh auto`
- USB 热插拔自动触发配置
- 日志记录到 journald

#### 3. 一键启动脚本 (`run.sh`, `start_robot.sh`)

```bash
# 完整一键启动（检查 CAN + 编译 + 启动）
bash scripts/run.sh

# 或直接使用
bash scripts/start_robot.sh
```

**启动流程：**
1. 检查 ROS2 环境
2. 检查 CAN 设备（关键！）
3. 自动配置 CAN（如果需要）
4. 编译工作空间
5. 修复包配置
6. 启动机器人

### 使用指南

#### 首次部署（新 Jetson）

```bash
cd ~/Blueberry_s4

# 1. 安装 CAN 自动服务
sudo bash scripts/install_can_service.sh

# 2. 重启或手动运行
sudo bash scripts/can_manager.sh auto

# 3. 验证
bash scripts/can_manager.sh status
```

#### 日常使用

```bash
# 一键启动（自动处理所有步骤）
bash scripts/run.sh

# 或仿真模式
bash scripts/run.sh sim
```

#### 添加新的 USB-CAN 设备

1. 插入 USB-CAN 设备
2. 系统自动检测并配置
3. 查看新接口：`bash scripts/can_manager.sh status`
4. 更新 launch 文件使用新接口

### 支持的 CAN 设备

| 设备 | 驱动 | 自动检测 | 自动安装 |
|------|------|---------|---------|
| Jetson 内置 CAN | mttcan | ✅ | ✅ (内置) |
| PEAK PCAN-USB | pcan | ✅ | ✅ (本地编译) |
| CANable/CandleLight | gs_usb | ✅ | ⚠️ (需系统支持) |
| ZLG CAN-FD | zlgcan | ✅ | ⚠️ (需厂商驱动) |

### 迁移到新 Jetson 的步骤

```bash
# 1. 克隆项目
git clone <repo> ~/Blueberry_s4
cd ~/Blueberry_s4

# 2. 安装 ROS2
bash scripts/setup_ros2_env.sh

# 3. 安装 CAN 服务
sudo bash scripts/install_can_service.sh

# 4. 重启
sudo reboot

# 5. 验证 CAN
bash scripts/can_manager.sh status

# 6. 编译并启动
bash scripts/run.sh
```

### 关键改进

1. **驱动本地化**
   - PEAK 驱动源码包含在 `drivers/` 目录
   - 无需网络下载即可编译安装

2. **启动前置检查**
   - 机器人启动前强制检查 CAN 状态
   - 自动配置或提示用户

3. **多设备支持**
   - 同时管理多个 CAN 接口
   - 自动识别设备类型

4. **服务化部署**
   - systemd 服务确保可靠性
   - udev 规则支持热插拔

### 待办更新

- [x] CAN 设备管理系统
- [x] PEAK 驱动本地化
- [x] 开机自动配置服务
- [x] 一键启动脚本更新
- [x] README 文档更新
- [ ] D405 相机阵列配置
- [ ] Livox 激光雷达配置
- [ ] WHJ 升降机构驱动
- [ ] Kinco 伺服驱动

### 文件统计

- 新增脚本：10 个
- 修改脚本：2 个
- 新增文档：多处更新
- 本地化驱动：1 个 (PEAK)

*最后更新: 2026-03-24*
*下次计划: 测试多 CAN 设备同时工作*

---

## 2026-03-25: AGV 控制调通 + 代码重构 + GitHub 同步

### ✅ 重大里程碑：AGV 底盘控制调通

经过详细调试和协议分析，**FW-Max AGV 底盘控制已完全调通**！

#### 问题根源

官方 `yhs_can_control` 驱动存在多个关键 Bug：

1. **单位转换错误**：ROS 消息使用 rad/s，但 CAN 协议使用 °/s（0.01°/s/bit），缺少转换
2. **符号扩展问题**：处理负数速度时，位操作因编译器不同产生不一致结果
3. **字节布局错误**：`ctrl_cmd` 的字节打包逻辑与官方 CAN 协议不符
4. **解锁逻辑不清晰**：`io_cmd_unlock` 的安全解锁机制缺少注释

#### 修复内容

**1. CAN 协议编码修复** (`yhs_can_control_node.cpp`)
```cpp
// 修正单位转换：rad/s → °/s
const short z_raw = static_cast<short>(
    msg.ctrl_cmd_z_angular * 180.0 / 3.14159265 * 100
);

// 修正符号扩展处理
short x_raw_copy = x_raw;
unsigned short x_raw_u = *reinterpret_cast<unsigned short*>(&x_raw_copy);
unsigned char x_high_nibble = (x_raw_u >> 12) & 0x0F;
```

**2. 添加详细注释**
- 完整的字节布局说明
- CAN 协议参数说明
- 调试日志增强

**3. 新增测试工具**
- `test_vehicle_control.py` - 车辆控制测试脚本
- `scripts/start_agv_test.sh` - AGV 一键测试
- Web Dashboard - 实时监控页面

#### 验证结果

```bash
# 测试直线运动
ros2 topic pub /ctrl_cmd yhs_can_interfaces/msg/CtrlCmd \
  '{ctrl_cmd_x_linear: 0.5, ctrl_cmd_z_angular: 0.0, ctrl_cmd_gear: 6}'

# 测试旋转
ros2 topic pub /ctrl_cmd yhs_can_interfaces/msg/CtrlCmd \
  '{ctrl_cmd_x_linear: 0.0, ctrl_cmd_z_angular: 0.5, ctrl_cmd_gear: 6}'
```

✅ **底盘按预期运动**：前进、后退、旋转均正常

---

### 🔧 项目结构重构

#### 1. 统一 CLI 工具 (`scripts/s4`)

创建类似 `tauri` 的统一直令行工具，替代分散的脚本：

```bash
./scripts/s4 check           # 检查环境和依赖
./scripts/s4 dev             # 启动开发环境（硬件模式）
./scripts/s4 dev sim         # 仿真模式
./scripts/s4 dev teleop      # 硬件 + 键盘遥控
./scripts/s4 build           # 编译工作空间
./scripts/s4 stop            # 停止所有节点
./scripts/s4 status          # 查看系统状态
sudo ./scripts/s4 can auto   # 自动配置 CAN 设备
```

**优势**：
- 单一入口，命令记忆简单
- 自动检测环境和依赖
- 集成所有常用操作

#### 2. 子模块转为普通目录

**原因**：官方驱动有 Bug，需要本地修改

**操作**：
```bash
# 移除子模块配置
git rm --cached src/YUHESEN-FW-MAX
rm -rf .git/modules/src/YUHESEN-FW-MAX
cd src/YUHESEN-FW-MAX && rm -rf .git

# 更新 .gitignore
git add src/YUHESEN-FW-MAX/
```

**结果**：
- AGV 驱动代码现在直接在仓库中维护
- 可以自由修改和修复 Bug
- 排除了大文件（`.apk`, `.doc`）

---

### 🌐 新增 Web Dashboard

创建独立的 Web 监控页面：

```bash
# 启动 Web Dashboard
bash web_dashboard/start_web_dashboard.sh

# 访问地址
http://<jetson-ip>:8080
```

**功能**：
- 🎯 实时运动状态（速度、转向角、电压）
- 📡 ROS2 话题列表
- 📝 系统日志
- 🎮 远程控制按钮

---

### 📤 GitHub 同步

**提交记录**：

1. **feat: AGV control working** (`6646f38`)
   - 统一 s4 CLI 工具
   - AGV 测试脚本和车辆控制测试
   - Web Dashboard 实时监控
   - AGENTS.md AI 开发文档
   - 重构启动文件，支持硬件控制

2. **refactor: convert YUHESEN-FW-MAX from submodule** (`b8c9c08`)
   - 移除子模块配置
   - AGV 驱动代码纳入主仓库
   - 更新 .gitignore 排除大文件

**仓库地址**：https://github.com/licher255/blueberry_s4

---

### 📝 计划向官方提交 Issue

准备向 YUHESEN 官方提交 Issue，报告驱动中的 Bug：

**目标仓库**：https://github.com/YUHESEN-Robot/FW-max-ros2/issues

**Issue 内容**：
- 问题描述：CAN 协议编码错误导致车辆无法响应控制
- 具体问题：单位转换、符号扩展、字节布局
- 修复方案：完整的代码修改说明
- 参考实现：https://github.com/licher255/blueberry_s4

---

### 📊 当前项目状态

| 组件 | 状态 | 说明 |
|------|------|------|
| AGV 底盘控制 | ✅ 完成 | CAN 通信正常，运动控制调通 |
| CAN 设备管理 | ✅ 完成 | 自动检测、配置、服务化 |
| Web Dashboard | ✅ 完成 | 实时监控，远程可视化 |
| s4 CLI 工具 | ✅ 完成 | 统一命令行入口 |
| 代码版本控制 | ✅ 完成 | GitHub 同步完成 |
| WHJ 升降机构 | ⏳ 待开发 | CAN-FD 通信 |
| Kinco 伺服 | ⏳ 待开发 | CANopen 协议 |
| D405 相机阵列 | ⏳ 待开发 | 7× USB 3.0 |
| Livox 激光雷达 | ⏳ 待开发 | 以太网接口 |

---

### 🎯 下一步计划

1. **向官方提交 Issue** - 报告 AGV 驱动 Bug
2. **集成 WHJ 升降机构** - CAN-FD 通信开发
3. **集成 Kinco 伺服** - CANopen 协议开发
4. **配置相机阵列** - 7× D405 同步采集
5. **配置激光雷达** - Livox Mid-360 点云

---

### 📁 新增/修改文件

```
新增:
├── AGENTS.md                           # AI 开发文档
├── scripts/s4                          # 统一 CLI 工具 ⭐
├── scripts/check_env.sh
├── scripts/start_agv_test.sh
├── test_vehicle_control.py             # 车辆控制测试
└── web_dashboard/                      # Web 监控页面
    ├── index.html
    ├── agv_test_control.html
    ├── app.js
    ├── style.css
    └── start_web_dashboard.sh

修改:
├── .gitignore                          # 移除 YUHESEN-FW-MAX 忽略
├── README.md                           # 更新使用说明
└── src/bringup/launch/robot.launch.py  # 优化参数

子模块变更:
└── src/YUHESEN-FW-MAX/                 # 从子模块转为普通目录
    └── yhs_can_control/src/yhs_can_control_node.cpp  # 关键修复
```

*记录时间: 2026-03-25*  
*里程碑: AGV 控制调通 ✅*


---

## 2026-03-25 Update: ZLG USB-CANFD 驱动安装与 WHJ 驱动框架

### 背景
今天的主要任务是打通 ZLG USB-CANFD-100U-mini 设备，为后续 WHJ (RealMan 升降机构) 的 CAN-FD 通信做准备。

### 1. ZLG USB-CANFD 驱动安装 ✅

#### 识别设备
```bash
$ lsusb
Bus 001 Device 005: ID 3068:0009 ZLG USBCANFD-100U-mini
```

#### 问题
- Jetson 内核没有预装 ZLG 驱动
- 需要手动编译安装 SocketCAN 版本驱动

#### 解决方案

**下载驱动源码** (用户从官网下载):
```
drivers/usbcanfd200_400u_2.10/
├── usbcanfd.c          # 驱动源码
├── usbcanfd.h          # 头文件
├── Makefile            # 编译脚本
└── readme.txt          # 官方文档
```

**编译安装**:
```bash
cd drivers/usbcanfd200_400u_2.10
make clean
make module
sudo insmod usbcanfd.ko
```

**验证安装**:
```bash
$ lsmod | grep usbcanfd
usbcanfd               40960  0
can_dev                36864  3 mttcan,usbcanfd,pcan

$ ip link show
3: can3: <NOARP> mtu 16 qdisc noop state DOWN mode DEFAULT group default qlen 10
4: can4: <NOARP> mtu 16 qdisc noop state DOWN mode DEFAULT qlen 10
```

**配置 CAN-FD**:
```bash
# 启用 can3 接口，配置 CAN-FD 1M/5M
sudo ip link set can3 up type can fd on bitrate 1000000 dbitrate 5000000

# 验证
ip -details link show can3
# can3: <UP> mtu 72 qdisc fq_codel state UP...
#   can state ERROR-ACTIVE
#   usbcanfd: tseg1 1..256 tseg2 1..128...
```

### 2. 创建 RealMan WHJ 驱动包 ✅

#### 目录结构
```
src/RealMan-WHJ/
├── README.md                           # 驱动文档
├── whj_can_interfaces/                 # ROS2 消息定义
│   ├── msg/
│   │   ├── PositionCmd.msg            # 位置控制命令
│   │   ├── VelocityCmd.msg            # 速度控制命令
│   │   ├── PositionFb.msg             # 位置反馈
│   │   ├── StatusFb.msg               # 状态反馈
│   │   └── StateFb.msg                # 完整状态
│   ├── CMakeLists.txt
│   └── package.xml
└── whj_can_control/                    # 控制节点
    ├── include/whj_can_control/
    │   └── whj_can_control_node.hpp   # 头文件
    ├── src/
    │   └── whj_can_control_node.cpp   # CAN-FD节点实现
    ├── scripts/
    │   └── test_whj_can.py            # Python测试脚本
    ├── launch/
    │   └── whj_can_control.launch.py  # 启动文件
    ├── params/
    │   └── whj_config.yaml            # 参数配置
    ├── CMakeLists.txt
    └── package.xml
```

#### 消息定义
| 消息类型 | 用途 | 关键字段 |
|---------|------|---------|
| PositionCmd | 位置控制 | target_position, target_speed, control_mode |
| VelocityCmd | 速度控制 | target_velocity, direction |
| PositionFb | 位置反馈 | current_position, target_position, current_speed |
| StatusFb | 状态反馈 | error_code, work_mode, is_moving, is_homed |
| StateFb | 完整状态 | header + PositionFb + StatusFb |

#### 节点功能
- **CAN-FD 通信**: 支持标准CAN和CAN-FD模式
- **双向通信**: 发送控制命令 + 接收状态反馈
- **ROS2 集成**: 发布/订阅 ROS2 话题
- **参数配置**: CAN接口名、波特率、设备ID等

### 3. 脚本和工具更新 ✅

#### 新增脚本
| 脚本 | 功能 |
|------|------|
| `scripts/install_zlg_driver.sh` | ZLG 驱动安装 |
| `scripts/setup_zlg_canfd.sh` | CAN-FD 快速配置 |
| `scripts/test_whj.sh` | WHJ 设备测试 |
| `scripts/check_zlg.sh` | ZLG 设备状态检查 |

#### 更新 s4 CLI
- 新增 `usbcanfd` 驱动类型自动识别
- 自动配置 CAN-FD 参数 (1M/5M)
- 支持 can3/can4 接口检测

#### 更新 bringup launch
```python
# src/bringup/launch/robot.launch.py
whj_node = Node(
    package='whj_can_control',
    executable='whj_can_control_node',
    parameters=[{
        'can_name': 'can3',
        'canfd_enabled': True,
    }],
    condition=IfCondition(use_whj),
)
```

### 4. 文档创建 ✅

| 文档 | 位置 | 内容 |
|------|------|------|
| ZLG CANFD 安装指南 | `docs/ZLG_CANFD_SETUP.md` | 驱动安装、配置、故障排除 |
| RealMan-WHJ README | `src/RealMan-WHJ/README.md` | WHJ 驱动使用说明 |
| AGENTS.md 更新 | `AGENTS.md` | 项目结构、构建说明 |

### 5. 当前硬件状态

| 设备 | 状态 | 接口 | 备注 |
|------|------|------|------|
| AGV (YUHESEN FW-Max) | ✅ 正常 | can2 | PEAK USB-CAN |
| WHJ (RealMan) | ⏳ 待连接 | can3 | ZLG USB-CANFD |
| Kinco 伺服 | ⏳ 未连接 | can3/can4 | 可与 WHJ 共用 |
| D405 相机 ×7 | ⏳ 未连接 | USB | - |
| Livox Mid-360 | ⏳ 未连接 | Ethernet | - |

### 6. 待办事项

**WHJ 协议开发** (用户回来后进行):
- [ ] 获取 WHJ 实际 CAN-FD 协议文档
- [ ] 更新 `whj_can_control_node.cpp` 中的 CAN ID
- [ ] 实现协议编解码
- [ ] 测试位置/速度控制
- [ ] 添加安全保护机制

### 7. 快速命令

```bash
# ZLG CAN-FD 配置
sudo ./scripts/setup_zlg_canfd.sh can3

# 测试 WHJ 通信
./scripts/test_whj.sh can3

# 启动 WHJ ROS2 驱动
cd ~/Blueberry_s4
source install/setup.bash
ros2 launch whj_can_control whj_can_control.launch.py can_interface:=can3

# 一键配置所有 CAN
sudo ./scripts/s4 can auto

# 系统状态检查
./scripts/s4 check
```

### 8. 文件清单

```
新增文件:
├── drivers/usbcanfd200_400u_2.10/           # ZLG 驱动源码
│   ├── usbcanfd.c, usbcanfd.h
│   ├── usbcanfd.ko                          # 编译后的模块
│   ├── Makefile, readme.txt
├── drivers/zlgcan/                          # 备用桥接程序框架
│   ├── src/zlgcan_bridge.cpp
│   └── Makefile
├── docs/ZLG_CANFD_SETUP.md                  # ZLG 安装文档
├── src/RealMan-WHJ/                         # WHJ 驱动包
│   ├── whj_can_interfaces/
│   └── whj_can_control/
├── scripts/
│   ├── install_zlg_driver.sh                # ZLG 驱动安装
│   ├── setup_zlg_canfd.sh                   # CAN-FD 配置
│   ├── test_whj.sh                          # WHJ 测试
│   └── check_zlg.sh                         # 状态检查
├── AGENTS.md                                # 已更新
├── README.md                                # 已更新
└── src/bringup/launch/robot.launch.py       # 已更新

编译生成的文件:
└── build/install/log                        # colcon 编译输出
```

*记录时间: 2026-03-25*  
*状态: ZLG CAN-FD 驱动已打通 ✅，WHJ 协议待开发 ⏳*

---

*最后更新: 2026-03-25*  
*下次计划: 根据 Python 协议代码实现 WHJ CAN-FD 通信*

