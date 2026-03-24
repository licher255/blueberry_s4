# Blueberry S4 - CAN 总线架构设计方案

## 📋 当前现状

| 设备 | 协议 | 波特率 | 当前连接 | 接口 |
|------|------|--------|----------|------|
| AGV (FW-Max) | CAN 2.0 | 500K | 独立 CAN | USB-CAN 或板载 |
| RealMan WHJ 升降 | CAN FD | 1000K | 共用 | ZLG CAN-FD2 USB |
| Kinco 伺服 | CAN 2.0 | 1000K | 共用 | ZLG CAN-FD2 USB |

**问题**: 3种不同的 CAN 配置，2个物理接口，协议不兼容。

---

## 🏗️ 方案对比

### 方案 1: 保持现状 (当前方案)

```
┌─────────────────┐     ┌──────────────────────────────────┐
│   AGV CAN       │     │      ZLG CAN-FD2 USB             │
│   (500K)        │     │  ┌─────────────┐  ┌────────────┐ │
│                 │     │  │  WHJ CAN-FD │  │ Kinco CAN  │ │
│  USB-CAN        │     │  │   (1000K)   │  │  (1000K)   │ │
│   Adapter       │     │  └─────────────┘  └────────────┘ │
└─────────────────┘     └──────────────────────────────────┘
```

**优点**:
- ✅ 无需改动硬件
- ✅ 软件已跑通

**缺点**:
- ❌ 占用 2 个 USB 口
- ❌ 软件需管理 2 个 CAN 接口
- ❌ 扩展性差（再加设备没接口）

**适用**: 短期验证阶段

---

### 方案 2: 全部合并到 CAN-FD (推荐优化)

**原理**: CAN FD 控制器可以向下兼容 CAN 2.0，同一总线可混合通信

```
┌─────────────────────────────────────────────────────────┐
│                    ZLG CAN-FD2 USB                      │
│                                                         │
│   Channel 0                    Channel 1               │
│  ┌─────────────────┐         ┌─────────────────────┐   │
│  │  CAN-FD Bus     │         │  CAN 2.0 Bus        │   │
│  │  (1000K + FD)   │         │  (500K)             │   │
│  │                 │         │                     │   │
│  │  WHJ (FD)       │         │  AGV (500K)         │   │
│  │  Kinco (1M)     │         │                     │   │
│  └─────────────────┘         └─────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**关键配置**:
```bash
# CAN-FD 通道 (Channel 0)
ip link set can0 up type can bitrate 1000000 dbitrate 5000000 fd on

# CAN 2.0 通道 (Channel 1)  
ip link set can1 up type can bitrate 500000
```

**优点**:
- ✅ 单 USB 设备，节省接口
- ✅ ZLG CAN-FD2 是工业级，稳定性好
- ✅ 物理隔离，协议不冲突
- ✅ WHJ 和 Kinco 同一总线，可做协调控制

**缺点**:
- ⚠️ AGV 仍需独立配置 500K（除非 AGV 支持 1M）

**可行性**:
- 需确认 AGV 控制器是否支持 **1Mbps** 或 **CAN FD**
- 如果 AGV 固件可配置波特率，这是最干净的方案

---

### 方案 3: CAN-CAN FD 桥接 (硬件网关)

使用 MCU/FPGA 做协议转换：

```
┌────────────────────────────────────────────────────────────┐
│                     STM32H7 / FPGA                         │
│                                                            │
│   CAN-FD 接口              桥接逻辑          CAN 接口      │
│  ┌───────────┐           ┌────────┐        ┌───────────┐  │
│  │ WHJ 1M FD │◄─────────►│Buffer/ │◄──────►│ AGV 500K  │  │
│  │ Kinco 1M  │           │Queue   │        │           │  │
│  └───────────┘           └────────┘        └───────────┘  │
│                                                            │
└────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    USB/ETH to Jetson
```

**优点**:
- ✅ 单接口连接上位机
- ✅ 可自定义协议转换逻辑
- ✅ 硬件时间戳同步

**缺点**:
- ❌ 需开发硬件/固件（2-4周）
- ❌ 增加故障点
- ❌ 成本增加 ¥200-500

**适用**: 大规模量产、对实时性要求极高

---

### 方案 4: ROS2 软件网关 (灵活方案)

不改硬件，纯软件实现统一接口：

```
┌─────────────────────────────────────────────────────────┐
│                      Jetson                             │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  can0 (AGV)  │  │  can1 (WHJ)  │  │  can2 (Kinco)│  │
│  │    500K      │  │   CAN-FD 1M  │  │    1M        │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                 │                  │          │
│         └─────────────────┴──────────────────┘          │
│                           │                             │
│                  ┌────────▼────────┐                    │
│                  │  CAN Gateway    │                    │
│                  │   ROS2 Node     │                    │
│                  │                 │                    │
│                  │  - 协议转换      │                    │
│                  │  - 时间同步      │                    │
│                  │  - 统一接口      │                    │
│                  └────────┬────────┘                    │
│                           │                             │
│                  ┌────────▼────────┐                    │
│                  │  /unified_cmd   │                    │
│                  │  /unified_state │                    │
│                  └─────────────────┘                    │
└─────────────────────────────────────────────────────────┘
```

**优点**:
- ✅ 无需改动硬件
- ✅ 可动态配置波特率
- ✅ 统一 ROS2 接口
- ✅ 可添加滤波、安全校验

**缺点**:
- ⚠️ 软件延迟增加 1-5ms（通常可接受）
- ⚠️ CPU 占用略高

**实现代码框架**:
```python
# can_gateway_node.py
import rclpy
from rclpy.node import Node
import can

class CANGateway(Node):
    def __init__(self):
        # AGV CAN (500K)
        self.agv_bus = can.interface.Bus(
            channel='can0', bustype='socketcan', bitrate=500000)
        
        # WHJ CAN-FD (1M)
        self.whj_bus = can.interface.Bus(
            channel='can1', bustype='socketcan', 
            bitrate=1000000, fd=True)
        
        # Kinco CAN (1M)
        self.kinco_bus = can.interface.Bus(
            channel='can2', bustype='socketcan', bitrate=1000000)
        
        # ROS2 Publishers/Subscribers
        self.unified_pub = self.create_publisher(
            UnifiedState, '/unified/state', 10)
        
    def route_message(self, msg, source):
        """路由并转换消息"""
        if source == 'agv':
            # 转换 AGV 状态到统一格式
            unified_msg = self.convert_agv(msg)
        elif source == 'whj':
            unified_msg = self.convert_whj(msg)
        # ...
        self.unified_pub.publish(unified_msg)
```

---

## 🎯 推荐方案

### 短期（1-2周）：保持现状 + 软件优化

保留当前硬件连接：
- AGV → 独立 CAN
- WHJ + Kinco → ZLG CAN-FD2

优化方向：
1. 开发 `can_gateway` ROS2 节点统一接口
2. 配置 udev 规则固定设备名（避免 `can0`/`can1` 错乱）
3. 添加 CAN 监控和故障恢复

### 中期（2-4周）：验证波特率统一

测试 AGV 是否支持 **1Mbps**:
```bash
# 尝试将 AGV 配置为 1M
# 如果成功，全部接到 CAN-FD 卡
```

**验证步骤**:
1. 查阅 AGV 手册确认支持的波特率
2. 联系深圳煜禾森科技（YUHESEN）技术支持确认是否可配置
3. 测试 1M 下的稳定性

### 长期（按需）：硬件网关

如果量产（>20套），考虑开发专用 CAN 网关板：
- 单 USB-C 连接
- 4路 CAN-FD
- 硬件时间戳
- 隔离保护

---

## 🔧 立即可做的优化

### 1. udev 规则（固定设备名）

```bash
# /etc/udev/rules.d/99-can.rules
# ZLG CAN-FD2 固定为 can_fd
SUBSYSTEM=="net", ATTRS{idVendor}=="xxxx", ATTRS{idProduct}=="xxxx", NAME="can_fd"

# AGV CAN 固定为 can_agv
SUBSYSTEM=="net", ATTRS{idVendor}=="yyyy", ATTRS{idProduct}=="yyyy", NAME="can_agv"
```

### 2. 启动脚本（自动配置）

```bash
#!/bin/bash
# setup_can.sh

# AGV CAN
sudo ip link set can_agv up type can bitrate 500000

# CAN-FD (WHJ + Kinco)
sudo ip link set can_fd up type can bitrate 1000000 dbitrate 5000000 fd on

echo "CAN interfaces configured"
ip link show can_agv can_fd
```

### 3. ROS2 Launch 统一启动

```python
# robot.launch.py
from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
    return LaunchDescription([
        # CAN Gateway
        Node(
            package='blueberry_can',
            executable='can_gateway',
            parameters=[{
                'agv_interface': 'can_agv',
                'agv_bitrate': 500000,
                'fd_interface': 'can_fd',
                'fd_bitrate': 1000000,
            }]
        ),
        # AGV 控制
        Node(
            package='fw_max_can',
            executable='can_bridge_py',
            parameters=[{'can_interface': 'can_agv'}]
        ),
        # WHJ 控制
        Node(
            package='realman_driver',
            executable='whj_node',
            parameters=[{'can_interface': 'can_fd'}]
        ),
        # Kinco 控制
        Node(
            package='kinco_driver',
            executable='servo_node',
            parameters=[{'can_interface': 'can_fd'}]
        ),
    ])
```

---

## 📊 方案选择矩阵

| 场景 | 推荐方案 | 理由 |
|------|----------|------|
**短期验证** | 方案 1 + 软件网关 | 不动硬件，快速验证
**中期稳定** | 方案 2 (如果 AGV 支持 1M) | 单接口，维护简单
**长期量产** | 方案 3 硬件网关 | 可靠性最高，成本最低
**灵活调试** | 方案 4 纯软件 | 便于调试和协议分析

---

## ❓ 需要确认的问题

1. **AGV 波特率可调吗？**
   - 查手册或联系 YUHESEN
   - 如果可以改 1M，强烈推荐方案 2

2. **WHJ 和 Kinco 会冲突吗？**
   - CAN ID 是否有重叠？
   - 需要分配不同的 ID 段

3. **实时性要求？**
   - 机械臂控制需要 < 10ms？
   - 如果要求极高，避免软件网关

4. **USB 带宽够吗？**
   - ZLG CAN-FD2 是 USB 2.0
   - 同时跑 7个 D405 + CAN-FD，检查总线占用
