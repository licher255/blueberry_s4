# CAN ID 测试指南

## 📋 已知的 CAN ID

| 设备 | Node ID | 接口 | 协议 |
|------|---------|------|------|
| **WHJ 升降** | 7 | can_fd (can1) | CAN FD |
| **Kinco 伺服** | 1 | can_fd (can1) | CANopen |
| **AGV** | ❓ 未知 | can_agv (can0) | 待确定 |

---

## 🔍 如何确定 AGV 的 CAN ID

### 方法 1: 使用 candump 监听

```bash
# 1. 配置 CAN 接口
sudo ip link set can0 up type can bitrate 500000

# 2. 开始监听
candump can0

# 3. 给 AGV 上电或操作遥控器
# 4. 观察输出的 CAN ID
```

**预期输出示例**：
```
  can0  100   [8]  00 00 00 00 00 00 00 00   # 可能是控制指令
  can0  200   [8]  01 00 00 00 00 00 00 00   # 可能是状态反馈
```

### 方法 2: 使用 Wireshark

```bash
# 安装
sudo apt install can-utils wireshark

# 捕获 CAN 帧
sudo modprobe can
sudo ip link set can0 up type can bitrate 500000

# 使用 wireshark 分析
sudo wireshark -k -i can0
```

### 方法 3: 参考 YUHESEN 手册

联系深圳煜禾森科技获取《FW-Max 通信协议手册》，通常会包含：
- 标准 CAN ID 定义
- 数据帧格式
- 通信频率

---

## 📝 记录测试结果

测试完成后，更新 `config/hardware_profile.yaml`：

```yaml
devices:
  agv:
    can_id:
      tx_motion: 0x???    # 填入实测值
      rx_state: 0x???     # 填入实测值
```

---

## 🎯 常见 CAN ID 模式

### 标准 CANopen (如 Kinco)
```
SDO 请求:  0x600 + NodeID
SDO 响应:  0x580 + NodeID
NMT 心跳:  0x700 + NodeID
```

### 自定义协议 (常见)
```
控制指令: 0x100 - 0x1FF
状态反馈: 0x200 - 0x2FF
```

---

## ⚠️ 注意事项

1. **确保 CAN 终端电阻**: AGV 和 CAN 适配器两端都需要 120Ω 终端电阻
2. **共地**: CAN 信号地 (CAN_GND) 必须连接
3. **波特率一致**: AGV 必须是 500K（如确认支持 1M 可改）
