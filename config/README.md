# Blueberry S4 - 配置系统说明

## 📁 文件结构

```
config/
├── hardware_profile.yaml    # 硬件配置文件（主要修改这里）
├── config_loader.py         # 配置读取工具
└── README.md               # 本文件
```

---

## 🚀 快速开始

### 1. 查看当前配置

```bash
cd ~/Blueberry_s4/config
python3 config_loader.py
```

输出示例：
```
============================================================
Blueberry S4 - 硬件配置信息
============================================================

📡 CAN 接口配置:
  • can_agv:
    设备: can0
    类型: CAN2.0
    波特率: 500K
  • can_fd:
    设备: can1
    类型: CANFD
    波特率: 1000K
    数据段: 5000K

🔧 CAN 初始化命令:
  sudo ip link set can0 up type can bitrate 500000
  sudo ip link set can1 up type can bitrate 1000000 dbitrate 5000000 fd on

🔌 已启用设备:
  • FW-Max (YUHESEN) -> can_agv
  • RealMan WHJ (RealMan) -> can_fd
  • Kinco Servo (Kinco) -> can_fd

📷 相机: 7x D405
🔍 雷达: Livox Mid-360
```

### 2. 生成 CAN 初始化脚本

```bash
python3 config_loader.py --script
sudo /tmp/setup_can.sh
```

---

## ⚙️ 修改配置

编辑 `hardware_profile.yaml` 文件：

```bash
nano ~/Blueberry_s4/config/hardware_profile.yaml
```

### 常用修改示例

#### 修改 CAN 波特率
```yaml
can_interfaces:
  - name: "can_agv"
    type: "can2.0"
    device: "can0"
    bitrate: 1000000    # 改成 1M（如果 AGV 支持）
```

#### 禁用某个设备
```yaml
devices:
  kinco_servo:
    enabled: false    # 改为 false 禁用
```

#### 修改 CAN ID
```yaml
devices:
  agv:
    can_id:
      tx_motion: 0x200    # 修改指令 ID
```

---

## 📋 配置项说明

### CAN 接口 (`can_interfaces`)

| 参数 | 说明 | 示例 |
|------|------|------|
| `name` | 接口标识名 | `can_agv`, `can_fd` |
| `type` | CAN 类型 | `can2.0` 或 `canfd` |
| `device` | Linux 设备名 | `can0`, `can1` |
| `bitrate` | 仲裁段波特率 | `500000`, `1000000` |
| `dbitrate` | 数据段波特率 (CAN-FD) | `5000000` |

### 设备 (`devices`)

| 参数 | 说明 | 示例 |
|------|------|------|
| `enabled` | 是否启用 | `true` / `false` |
| `can_interface` | 使用的 CAN 接口 | `can_agv`, `can_fd` |
| `can_id` | CAN 通信 ID | 见具体设备 |

### 调试 (`debug`)

```yaml
debug:
  simulation:
    enabled: true     # 仿真模式（不连接硬件）
  can_debug:
    enabled: true     # 打印所有 CAN 帧
```

---

## 🔧 在代码中使用

### Python（不依赖 ROS2）

```python
from config.config_loader import HardwareConfig

# 加载配置
config = HardwareConfig()

# 获取 CAN 接口信息
for iface in config.get_can_interfaces():
    print(f"{iface['name']}: {iface['device']} @ {iface['bitrate']}")

# 获取设备映射
mapping = config.get_device_can_mapping()
# {'agv': 'can_agv', 'whj_lifter': 'can_fd', ...}

# 检查是否仿真
if config.is_simulation():
    print("仿真模式，不连接真实硬件")
```

### ROS2 节点中使用

```python
import yaml
from ament_index_python.packages import get_package_share_directory
import os

class MyNode(Node):
    def __init__(self):
        super().__init__('my_node')
        
        # 加载配置文件
        config_path = os.path.join(
            get_package_share_directory('my_package'),
            'config',
            'hardware_profile.yaml'
        )
        
        with open(config_path, 'r') as f:
            self.config = yaml.safe_load(f)
        
        # 读取参数
        agv_config = self.config['devices']['agv']
        can_iface = agv_config['can_interface']
        can_id = agv_config['can_id']['tx_motion']
        
        self.get_logger().info(f"AGV 使用 {can_iface}, ID: 0x{can_id:03X}")
```

---

## 📝 最佳实践

1. **版本控制**: 将 `hardware_profile.yaml` 提交到 git，记录配置变更
2. **环境区分**: 可以创建多个配置文件
   - `hardware_profile_sim.yaml` - 仿真配置
   - `hardware_profile_lab.yaml` - 实验室配置
   - `hardware_profile_field.yaml` - 现场配置
3. **备份**: 修改前备份原配置
   ```bash
   cp hardware_profile.yaml hardware_profile.yaml.bak
   ```

---

## ❓ 常见问题

### Q: 修改配置后需要重启吗？
**A**: 
- CAN 配置需要重启接口：`sudo ip link set can0 down && sudo ip link set can0 up`
- ROS2 节点需要重启才能读取新配置

### Q: 如何添加新设备？
**A**: 在 `devices:` 下添加新节点，参考现有格式

### Q: YAML 格式报错？
**A**: 
- 缩进必须是空格，不能用 Tab
- 冒号后必须有空格 `key: value`
- 可以用在线工具检查：https://www.yamllint.com/
