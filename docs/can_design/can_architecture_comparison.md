# Blueberry S4 - CAN 总线架构

## 📋 当前架构（已确定）

### 硬件连接

| 设备 | 协议 | 波特率 | 帧类型 | CAN ID | 物理接口 |
|------|------|--------|--------|--------|----------|
| **AGV (FW-Max)** | CAN 2.0 | 500K | **扩展帧 (29-bit)** | 0x18C4xxxx | PEAK PCAN |
| **Kinco 伺服** | CAN 2.0 | 500K | **标准帧 (11-bit)** | 0x181, 0x281 | PEAK PCAN |
| **WHJ 升降** | **CAN-FD** | **1M/5M** | CAN-FD 帧 | Node 7 | ZLG CAN-FD |

### 总线分离原因

**为什么需要两个物理接口？**

1. **波特率不兼容**
   - AGV + Kinco: 500K (标准 CAN)
   - WHJ: 1M/5M CAN-FD
   - **无法共用同一总线**

2. **协议差异**
   - AGV: 自定义协议，扩展帧 (29-bit)
   - Kinco: CANopen 标准帧 (11-bit)
   - WHJ: CAN-FD 自定义协议

3. **电气隔离**
   - PEAK PCAN: 连接 AGV + Kinco（底盘相关）
   - ZLG CAN-FD: 连接 WHJ（升降机构）

---

## 🔌 详细连接图

```
Jetson
├── PEAK PCAN (USB) ───────┬──→ AGV 底盘 (CAN 扩展帧 0x18C4xxxx)
│   500K 标准 CAN          │
│   29-bit + 11-bit 混合   └──→ Kinco 旋转电机 (CANopen 0x181/0x281)
│
└── ZLG CAN-FD (USB) ──────→ WHJ 升降机构 (CAN-FD 1M/5M)
    Node ID 7
```

### PEAK PCAN 总线详情 (500K)

**AGV (扩展帧 29-bit)**
```
发送 (TX):
  0x18C4D1D0 - 运动控制指令
  0x18C4D2D0 - 转向控制指令
  0x18C4D7D0 - IO 控制指令

接收 (RX):
  0x98C4D1EF - 控制反馈
  0x98C4D2EF - 转向反馈
  0x98C4DAEF - IO 反馈
  0x98C4E1EF - BMS 电池反馈
```

**Kinco (标准帧 11-bit, CANopen)**
```
Node ID: 1

TPDO1 (状态/告警): 0x181
  - Byte 0-1: Status Word
  - Byte 2-3: Warning Word

TPDO2 (位置/速度): 0x281
  - Byte 0-3: 实际位置 (编码器计数)
  - Byte 4-7: 实际速度 (RPM)

RPDO1 (控制): 0x201
  - 发送控制指令

NMT/心跳: 0x701
  - 节点状态监控
```

**注意**: AGV (扩展帧) 和 Kinco (标准帧) 共用同一物理总线，但 ID 空间不冲突

### ZLG CAN-FD 总线详情 (1M/5M)

**WHJ (CAN-FD)**
```
Node ID: 7

读取命令:  0x07 (标准帧)
写入命令:  0x07 (标准帧)
数据长度:  最大 64 字节 (CAN-FD 特性)

寄存器:
  0x0A - 使能控制
  0x0F - 清除错误
  0x36/0x37 - 目标位置 (32-bit)
```

---

## 📊 帧类型对比

| 特性 | AGV | Kinco | WHJ |
|------|-----|-------|-----|
| **帧格式** | 扩展帧 (29-bit) | 标准帧 (11-bit) | CAN-FD |
| **协议** | YUHESEN 自定义 | CANopen | RealMan 自定义 |
| **波特率** | 500K | 500K | 1M (仲裁) / 5M (数据) |
| **ID 示例** | 0x18C4D1D0 | 0x181, 0x281 | 0x07 |
| **数据长度** | 8 字节 | 8 字节 | 最大 64 字节 |

### 扩展帧 vs 标准帧

**扩展帧 (29-bit ID) - AGV**
```
ID 结构: 0x18C4D1D0
  - 前缀: 0x18C4 (厂商定义)
  - 功能: D1 (运动控制)
  - 方向: D0 (发送)

范围: 0x00000000 - 0x1FFFFFFF
```

**标准帧 (11-bit ID) - Kinco**
```
ID 结构: 0x181 (TPDO1 for Node 1)
  - 0x180 + Node ID = TPDO1
  - 0x200 + Node ID = RPDO1
  - 0x280 + Node ID = TPDO2
  - 0x700 + Node ID = NMT/心跳

范围: 0x000 - 0x7FF
```

---

## 🛠️ 配置方法

### PEAK PCAN (AGV + Kinco)

```bash
# 配置接口
sudo ip link set can3 up type can bitrate 500000

# 验证
ip link show can3
candump can3

# 测试 AGV (扩展帧)
cansend can3 18C4D1D0#01F4000000000000

# 测试 Kinco (标准帧)
cansend can3 201#0106100000000000
```

### ZLG CAN-FD (WHJ)

```bash
# 配置接口
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on

# 验证
ip link show can2
candump can2

# 测试 WHJ
cansend can2 007#020A0000
```

---

## ⚠️ 常见误区

### 误区 1: "所有设备可以接在同一总线"
**错误**！WHJ 需要 CAN-FD 1M，AGV/Kinco 只有 500K，波特率不匹配。

### 误区 2: "扩展帧和标准帧不能共存"
**错误**！CAN 2.0 支持扩展帧和标准帧混合，AGV (29-bit) 和 Kinco (11-bit) 可以共用 PEAK 总线。

### 误区 3: "Kinco ID 0x181 是扩展帧"
**错误**！0x181 是标准帧 11-bit ID (0x000-0x7FF)，遵循 CANopen 规范。

### 误区 4: "CAN-FD 可以向下兼容 CAN 2.0"
**部分正确**。CAN-FD 控制器可以接收 CAN 2.0 帧，但 CAN 2.0 控制器无法解析 CAN-FD 帧。

---

## 🔧 故障排除

### 问题: Kinco 无响应，但 AGV 正常

**原因**: 可能混淆了标准帧和扩展帧

**检查**:
```bash
# 查看 CAN 帧格式
candump can3 -x
# -x 显示帧类型 (S=标准帧, E=扩展帧)

# 应该看到:
# can3  181  [8]  ...  ← 标准帧 (Kinco)
# can3  98C4DAEF  [8]  ...  ← 扩展帧 (AGV)
```

### 问题: WHJ 通信失败

**原因**: 可能用普通 CAN 模式打开 CAN-FD

**检查**:
```bash
# 确认是 CAN-FD 模式
ip -details link show can2
# 应该显示: can fd on

# 用正确模式发送
cansend can2 007#020A0000
```

### 问题: 总线冲突

**原因**: AGV 和 Kinco ID 可能冲突

**解决**:
- AGV: 扩展帧 (0x18C4xxxx)，不会与标准帧冲突
- Kinco: 0x181/0x281，确保没有其他 CANopen 设备使用 Node ID 1

---

## 📚 参考

- [CANopen 规范](https://www.can-cia.org/canopen/)
- [CAN-FD 介绍](https://www.csselectronics.com/pages/can-fd-flexible-data-rate-intro-basics)
- [PEAK PCAN 驱动文档](../drivers/peak-linux-driver-8.18.0/README)
- [ZLG CANFD 文档](../docs/ZLG_CANFD_SETUP.md)

---

*最后更新: 2026-04-01*
