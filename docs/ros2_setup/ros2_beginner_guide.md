# ROS2 新手入门指南 - Blueberry S4

## 🎯 什么是 ROS2？

**ROS2 (Robot Operating System 2)** 是机器人软件框架，就像机器人的"操作系统"。

### 核心概念（简单理解）

| 概念 | 类比 | 说明 |
|------|------|------|
| **Node** | 手机 App | 一个独立运行的程序，比如相机驱动、导航程序 |
| **Topic** | 微信群 | 节点间通信的"话题"，比如 "/camera/image" |
| **Message** | 微信消息 | 话题中传递的数据格式 |
| **Package** | App 安装包 | 功能集合，比如相机驱动包 |
| **Workspace** | 手机桌面 | 所有代码组织的地方 |

---

## 📁 ROS2 工作空间结构

```
ros2_ws/                          # 工作空间根目录
├── build/                        # 编译生成的临时文件（自动生成）
├── install/                      # 编译结果（可执行文件在这里）
├── log/                          # 编译日志
└── src/                          # 你的源代码放这里
    └── blueberry_s4/             # 我们的项目包
        ├── package.xml           # 包描述文件
        ├── setup.py              # Python 包配置
        ├── resource/             # 资源文件
        └── blueberry_s4/         # Python 代码
            ├── __init__.py
            ├── can_node.py       # CAN 通信节点
            └── agv_driver.py     # AGV 驱动
```

---

## 🚀 第一步：安装 ROS2 Humble

### 1.1 设置 locale
```bash
sudo apt update && sudo apt install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8
```

### 1.2 添加 ROS2 源
```bash
# 安装依赖
sudo apt install -y software-properties-common
sudo add-apt-repository universe
sudo apt update

# 添加 ROS2 GPG key
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg

# 添加源
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu jammy main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null

sudo apt update
```

### 1.3 安装 ROS2
```bash
# 完整桌面版（推荐，包含常用工具）
sudo apt install -y ros-humble-desktop

# 或者最小版本（节省空间）
# sudo apt install -y ros-humble-ros-base
```

### 1.4 环境设置
```bash
# 每次打开终端都需要 source（或添加到 .bashrc）
echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc
source ~/.bashrc

# 安装开发工具
sudo apt install -y python3-colcon-common-extensions python3-rosdep
```

### 1.5 初始化 rosdep
```bash
sudo rosdep init
rosdep update
```

---

## 🏗️ 第二步：创建工作空间

```bash
# 创建工作空间
cd ~/
mkdir -p ros2_ws/src
cd ros2_ws

# 创建我们的项目包
cd src
ros2 pkg create blueberry_s4 \
  --build-type ament_python \
  --dependencies rclpy std_msgs geometry_msgs \
  --description "Blueberry S4 Robot Control Package" \
  --license MIT \
  --maintainer-name "Your Name" \
  --maintainer-email "your@email.com"
```

**解释参数**：
- `--build-type ament_python`: 纯 Python 包
- `--dependencies`: 依赖的其他包
- `rclpy`: ROS2 Python 客户端库

---

## 📝 第三步：创建第一个节点

创建 `ros2_ws/src/blueberry_s4/blueberry_s4/can_bridge_node.py`：

```python
#!/usr/bin/env python3
"""
CAN Bridge Node - ROS2 节点示例
订阅 ROS2 话题，发送到 CAN 总线
"""

import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Twist
import can


class CANBridgeNode(Node):
    """CAN 桥接节点"""
    
    def __init__(self):
        super().__init__('can_bridge_node')
        
        # 声明参数（从配置文件读取）
        self.declare_parameter('can_interface', 'can0')
        self.declare_parameter('can_bitrate', 500000)
        
        # 获取参数
        can_iface = self.get_parameter('can_interface').value
        bitrate = self.get_parameter('can_bitrate').value
        
        self.get_logger().info(f'初始化 CAN 接口: {can_iface} @ {bitrate}')
        
        # 初始化 CAN 总线
        try:
            self.can_bus = can.interface.Bus(
                channel=can_iface, 
                bustype='socketcan',
                bitrate=bitrate
            )
            self.get_logger().info('CAN 总线连接成功')
        except Exception as e:
            self.get_logger().error(f'CAN 连接失败: {e}')
            raise
        
        # 订阅速度指令话题
        self.subscription = self.create_subscription(
            Twist,                          # 消息类型
            '/cmd_vel',                     # 话题名
            self.cmd_vel_callback,          # 回调函数
            10                              # 队列大小
        )
        
        # 定时器：每秒打印一次状态
        self.timer = self.create_timer(1.0, self.timer_callback)
        
        self.get_logger().info('CAN Bridge Node 已启动')
    
    def cmd_vel_callback(self, msg):
        """收到速度指令时的回调"""
        # linear.x: 前进/后退速度
        # angular.z: 旋转速度
        
        self.get_logger().info(
            f'收到指令: 速度={msg.linear.x:.2f} m/s, '
            f'转向={msg.angular.z:.2f} rad/s'
        )
        
        # TODO: 将速度转换为 CAN 帧发送给 AGV
        # can_msg = can.Message(
        #     arbitration_id=0x100,
        #     data=[...],
        #     is_extended_id=False
        # )
        # self.can_bus.send(can_msg)
    
    def timer_callback(self):
        """定时器回调"""
        self.get_logger().debug('节点运行中...')
    
    def destroy_node(self):
        """节点销毁时的清理"""
        if hasattr(self, 'can_bus'):
            self.can_bus.shutdown()
        super().destroy_node()


def main(args=None):
    """主函数"""
    rclpy.init(args=args)
    
    node = CANBridgeNode()
    
    try:
        # 保持节点运行
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info('收到 Ctrl+C，正在关闭...')
    finally:
        # 清理资源
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
```

---

## ⚙️ 第四步：配置包

### 4.1 修改 setup.py

编辑 `ros2_ws/src/blueberry_s4/setup.py`：

```python
from setuptools import setup

package_name = 'blueberry_s4'

setup(
    name=package_name,
    version='0.1.0',
    packages=[package_name],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Your Name',
    maintainer_email='your@email.com',
    description='Blueberry S4 Robot Control Package',
    license='MIT',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            # 注册命令
            'can_bridge = blueberry_s4.can_bridge_node:main',
        ],
    },
)
```

### 4.2 添加依赖

编辑 `ros2_ws/src/blueberry_s4/package.xml`，在 `<test_depend>` 前添加：

```xml
  <exec_depend>python3-can</exec_depend>
```

---

## 🔨 第五步：编译和运行

### 5.1 安装依赖
```bash
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -y
```

### 5.2 编译
```bash
colcon build --packages-select blueberry_s4
```

### 5.3 加载环境
```bash
source install/setup.bash
```

### 5.4 运行节点
```bash
# 方式 1: 使用 ros2 run
ros2 run blueberry_s4 can_bridge

# 方式 2: 带参数
ros2 run blueberry_s4 can_bridge --ros-args -p can_interface:=can1 -p can_bitrate:=1000000
```

---

## 🎮 第六步：测试节点

开 **3 个终端** 测试：

### 终端 1：运行节点
```bash
source ~/ros2_ws/install/setup.bash
ros2 run blueberry_s4 can_bridge
```

### 终端 2：查看话题列表
```bash
source ~/ros2_ws/install/setup.bash
ros2 topic list
```

### 终端 3：发送测试指令
```bash
source ~/ros2_ws/install/setup.bash

# 发送前进指令
ros2 topic pub /cmd_vel geometry_msgs/Twist '{linear: {x: 1.0}, angular: {z: 0.0}}' --once

# 发送左转指令
ros2 topic pub /cmd_vel geometry_msgs/Twist '{linear: {x: 0.0}, angular: {z: 0.5}}' --once
```

---

## 📝 常用命令速查

```bash
# ========== 编译 ==========
colcon build                              # 编译整个工作空间
colcon build --packages-select <包名>     # 只编译指定包
colcon build --symlink-install           # 开发模式（修改代码无需重新编译）

# ========== 运行 ==========
ros2 run <包名> <节点名>                  # 运行节点
ros2 launch <包名> <启动文件>             # 运行启动文件

# ========== 话题 ==========
ros2 topic list                           # 列出所有话题
ros2 topic echo <话题名>                  # 监听话题内容
ros2 topic pub <话题名> <消息类型> <数据>  # 发送话题消息

# ========== 节点 ==========
ros2 node list                            # 列出所有节点
ros2 node info <节点名>                   # 查看节点信息

# ========== 参数 ==========
ros2 param list                           # 列出所有参数
ros2 param get <节点名> <参数名>          # 获取参数值
ros2 param set <节点名> <参数名> <值>     # 设置参数值
```

---

## 🎯 下一步

1. **完成本指南的所有步骤**
2. **测试 CAN 通信节点**
3. **添加 AGV 控制逻辑**
4. **创建启动文件（Launch）**

---

## ❓ 常见问题

### Q: `command not found: ros2`
**A**: 没有 source ROS2 环境
```bash
source /opt/ros/humble/setup.bash
```

### Q: `ModuleNotFoundError: No module named 'can'`
**A**: 安装 python-can
```bash
pip3 install python-can
```

### Q: 编译报错
**A**: 先清理再编译
```bash
cd ~/ros2_ws
rm -rf build install log
colcon build
```
