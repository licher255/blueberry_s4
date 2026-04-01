# CAN ID 参考指南

## 📋 已确定的 CAN ID

### AGV (煜禾森 FW-Max)

| 方向 | CAN ID | 说明 | 帧类型 |
|------|--------|------|--------|
| TX | `0x18C4D1D0` | 运动控制指令 | 扩展帧 (29-bit) |
| TX | `0x18C4D2D0` | 转向控制指令 | 扩展帧 (29-bit) |
| TX | `0x18C4D7D0` | IO 控制指令 | 扩展帧 (29-bit) |
| RX | `0x98C4D1EF` | 控制反馈 | 扩展帧 (29-bit) |
| RX | `0x98C4D2EF` | 转向反馈 | 扩展帧 (29-bit) |
| RX | `0x98C4DAEF` | IO 反馈 | 扩展帧 (29-bit) |
| RX | `0x98C4E1EF` | BMS 电池反馈 | 扩展帧 (29-bit) |
| RX | `0x98C4E2EF` | BMS 标志反馈 | 扩展帧 (29-bit) |

**接口**: PEAK PCAN (can_agv) @ 500K

---

### Kinco 伺服 (CANopen)

Node ID: **1**

| 功能 | CAN ID | 说明 | 帧类型 |
|------|--------|------|--------|
| TX (RPDO) | `0x201` | 控制指令接收 | 标准帧 (11-bit) |
| TX (RPDO2) | `0x301` | 位置指令接收 | 标准帧 (11-bit) |
| RX (TPDO1) | `0x181` | 状态字/告警字发送 | 标准帧 (11-bit) |
| RX (TPDO2) | `0x281` | 位置/速度发送 | 标准帧 (11-bit) |
| RX (EMCY) | `0x081` | 紧急报文 | 标准帧 (11-bit) |
| RX (NMT) | `0x701` | 心跳/状态 | 标准帧 (11-bit) |

**接口**: PEAK PCAN (can_agv) @ 500K（与 AGV 共用）

**注意**: Kinco 使用标准帧，AGV 使用扩展帧，两者 ID 空间不冲突

---

### WHJ 升降

Node ID: **7**

| 方向 | CAN ID | 说明 | 帧类型 |
|------|--------|------|--------|
| TX/RX | `0x07` | 读写命令 | CAN-FD |

**接口**: ZLG CAN-FD (can_fd) @ 1M/5M

**协议**: RealMan 自定义协议（非 CANopen）

---

## 🔍 如何监听 CAN 数据

### AGV + Kinco (PEAK PCAN)

```bash
# 配置接口
sudo ip link set can3 up type can bitrate 500000

# 监听所有帧（显示扩展帧标志）
candump can3 -x

# 预期输出
can3  181   [8]  04 00 00 00 00 00 00 00   # Kinco TPDO1 (标准帧)
can3  98C4D1EF  [8]  ...                    # AGV 反馈 (扩展帧)
```

### WHJ (ZLG CAN-FD)

```bash
# 配置接口
sudo ip link set can2 up type can bitrate 1000000 dbitrate 5000000 fd on

# 监听
candump can2

# 预期输出
can2  007  [4]  02 0A 00 00   # WHJ 使能命令
```

---

## 📝 ID 冲突检查

当前架构 ID 分配：

| 总线 | 设备 | ID 范围 | 冲突风险 |
|------|------|---------|----------|
| PEAK (500K) | AGV | 0x18C4xxxx (扩展帧) | 无 |
| PEAK (500K) | Kinco | 0x181, 0x281, 0x701 (标准帧) | 无 |
| ZLG (1M FD) | WHJ | 0x07 | 无 |

**结论**: 无 ID 冲突，各设备使用独立的 ID 空间

---

## 🛠️ 测试命令

### AGV 测试

```bash
# 解锁 AGV
cansend can3 18C4D7D0#020000000000001002
cansend can3 18C4D7D0#020000000000001012
cansend can3 18C4D7D0#000000000000002020
cansend can3 18C4D7D0#000000000000003030

# 前进 (0.5m/s)
cansend can3 18C4D1D0#461FC0630F0010E5
```

### Kinco 测试

```bash
# 发送 NMT 启动
cansend can3 000#0100

# 使能绝对位置模式
cansend can3 201#013F100000000000

# 移动到位 (示例)
cansend can3 301#0000000040F00000
```

### WHJ 测试

```bash
# 使能
cansend can2 007#020A0000

# 移动 (示例)
# 具体命令格式参考 WHJ 协议文档
```

---

## 📚 参考

- [CAN 架构说明](./can_architecture_comparison.md)
- [AGENTS.md](../../AGENTS.md) - 完整 CAN ID 表格
- [WHJ 协议](../REALMAN-WHJ/whj_protocol.md)
- [Kinco CANopen 手册](../third%20party/Kinco%20FD1X5驱动器使用手册%2020250514.pdf)

---

*最后更新: 2026-04-01*
