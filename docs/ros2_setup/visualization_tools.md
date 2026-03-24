# ROS2 可视化工具指南

## 🎯 常用可视化工具

| 工具 | 用途 | 安装 | 启动命令 |
|------|------|------|----------|
| **RViz2** | 3D 可视化（机器人、点云、路径） | `ros-humble-rviz2` | `rviz2` |
| **rqt** | 多功能 GUI（话题、节点、日志） | `ros-humble-rqt*` | `rqt` |
| **PlotJuggler** | 数据绘图 | 需单独安装 | `ros2 run plotjuggler plotjuggler` |
| **Foxglove** | 现代 Web 界面 | 浏览器访问 | `foxglove-bridge` |

---

## 📊 1. RViz2 - 3D 可视化

### 安装
```bash
sudo apt install -y ros-humble-rviz2 ros-humble-rviz-common
```

### 启动
```bash
# 方式 1: 直接启动
rviz2

# 方式 2: 带配置文件
rviz2 -d ~/s4_ws/src/bringup/config/s4.rviz
```

### 常用显示项

| 插件 | 用途 | 对应话题 |
|------|------|----------|
| RobotModel | 显示机器人 3D 模型 | `/robot_description` |
| TF | 显示坐标系变换 | `/tf` |
| LaserScan | 显示激光雷达 | `/scan` |
| PointCloud2 | 显示点云 | `/livox/lidar` |
| Image | 显示相机图像 | `/camera/color/image_raw` |
| Path | 显示导航路径 | `/plan` |
| Marker | 显示标记点 | `/visualization_marker` |

### 配置文件示例
```yaml
# 保存到 ~/s4_ws/src/bringup/config/s4.rviz
Panels:
  - Class: rviz_common/Displays
    Name: Displays
  - Class: rviz_common/Selection
    Name: Selection
  - Class: rviz_common/Tool Properties
    Name: Tool Properties
  - Class: rviz_common/Views
    Name: Views
Visualization Manager:
  Displays:
    - Alpha: 0.5
      Cell Size: 1
      Class: rviz_default_plugins/Grid
      Color: 160; 160; 164
      Line Style:
        Line Width: 0.03
        Value: Lines
      Name: Grid
      Value: true
    - Alpha: 1
      Class: rviz_default_plugins/RobotModel
      Description Source: Topic
      Description Topic:
        Value: /robot_description
      Name: RobotModel
      Value: true
    - Class: rviz_default_plugins/TF
      Name: TF
      Value: true
  Enabled: true
  Tools:
    - Class: rviz_default_plugins/Interact
    - Class: rviz_default_plugins/MoveCamera
    - Class: rviz_default_plugins/Select
    - Class: rviz_default_plugins/FocusCamera
    - Class: rviz_default_plugins/Measure
    - Class: rviz_default_plugins/SetInitialPose
    - Class: rviz_default_plugins/SetGoal
  Value: true
  Views:
    Current:
      Class: rviz_default_plugins/Orbit
      Name: Current View
Window Geometry:
  Height: 1016
  Width: 1853
```

---

## 📈 2. rqt - 多功能 GUI

### 安装
```bash
sudo apt install -y ros-humble-rqt \
    ros-humble-rqt-common-plugins \
    ros-humble-rqt-graph \
    ros-humble-rqt-topic \
    ros-humble-rqt-console \
    ros-humble-rqt-reconfigure
```

### 常用插件

#### rqt_graph - 节点关系图
```bash
ros2 run rqt_graph rqt_graph
```
显示所有节点和话题的连接关系，像流程图一样。

#### rqt_topic - 话题监视器
```bash
ros2 run rqt_topic rqt_topic
```
实时显示所有话题的消息频率和内容。

#### rqt_console - 日志查看
```bash
ros2 run rqt_console rqt_console
```
集中查看所有节点的日志输出。

#### rqt_reconfigure - 动态参数调整
```bash
ros2 run rqt_reconfigure rqt_reconfigure
```
运行时修改节点参数，无需重启。

#### 启动完整 rqt
```bash
rqt
# 然后 Plugins 菜单选择需要的插件
```

---

## 📉 3. PlotJuggler - 数据绘图

### 安装
```bash
sudo apt install -y ros-humble-plotjuggler \
    ros-humble-plotjuggler-ros
```

### 启动
```bash
ros2 run plotjuggler plotjuggler
```

### 用途
- 实时绘制话题数据曲线
- 保存/加载绘图配置
- 分析传感器数据（速度、电流、温度等）

---

## 🌐 4. Foxglove Studio - 现代 Web 界面

### 特点
- ✅ 基于浏览器，无需安装
- ✅ 支持远程访问
- ✅ 界面美观现代
- ✅ 实时和回放模式

### 安装 Bridge
```bash
sudo apt install -y ros-humble-foxglove-bridge
```

### 启动
```bash
# 终端 1: 启动 bridge
ros2 launch foxglove_bridge foxglove_bridge_launch.xml

# 终端 2: 打开浏览器访问
# http://localhost:8765
# 或在其他电脑访问 http://<jetson-ip>:8765
```

### 使用步骤
1. 浏览器打开 https://studio.foxglove.dev
2. 选择 "Open connection"
3. 输入 Jetson 的 IP 和端口 8765
4. 即可看到可视化界面

---

## 🖥️ Jetson 显示方案

### 方案 A: 直接连接显示器（如果有）
```bash
# 直接启动
rviz2
rqt
```

### 方案 B: SSH X11 转发（推荐）

**在本地电脑（Linux/Mac）**：
```bash
# 使用 -X 参数连接 Jetson
ssh -X hkclr@<jetson-ip>

# 然后启动 RViz
rviz2
```

**注意**：
- 需要本地电脑有 X Server
- Mac 需要安装 XQuartz
- Windows 需要 MobaXterm 或 VcXsrv

### 方案 C: VNC 远程桌面

**在 Jetson 上安装**：
```bash
sudo apt install -y tigervnc-standalone-server tigervnc-viewer

# 设置密码
vncpasswd

# 启动 VNC 服务器
vncserver :1 -geometry 1920x1080 -depth 24
```

**在本地电脑连接**：
```bash
# 使用 VNC Viewer 或 Remmina
# 连接到 <jetson-ip>:5901
```

### 方案 D: Foxglove Web 界面（最简单）

不需要显示器，直接用浏览器访问：
```bash
# 在 Jetson 上
ros2 launch foxglove_bridge foxglove_bridge_launch.xml

# 在本地电脑浏览器打开
# https://studio.foxglove.dev
# 然后连接 ws://<jetson-ip>:8765
```

---

## 🎮 S4 项目可视化配置

### 创建可视化启动文件

创建 `~/s4_ws/src/bringup/launch/viz.launch.py`：

```python
#!/usr/bin/env python3
"""S4 可视化启动文件"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution
from launch_ros.actions import Node
from launch_ros.substitutions import FindPackageShare


def generate_launch_description():
    # 参数
    use_rviz = LaunchConfiguration('use_rviz')
    use_rqt = LaunchConfiguration('use_rqt')
    use_foxglove = LaunchConfiguration('use_foxglove')
    
    # RViz 配置路径
    rviz_config = PathJoinSubstitution([
        FindPackageShare('bringup'),
        'config',
        's4.rviz'
    ])
    
    return LaunchDescription([
        # 参数声明
        DeclareLaunchArgument('use_rviz', default_value='true'),
        DeclareLaunchArgument('use_rqt', default_value='false'),
        DeclareLaunchArgument('use_foxglove', default_value='false'),
        
        # RViz2
        Node(
            package='rviz2',
            executable='rviz2',
            name='rviz2',
            arguments=['-d', rviz_config],
            condition=IfCondition(use_rviz),
            output='screen'
        ),
        
        # Foxglove Bridge
        Node(
            package='foxglove_bridge',
            executable='foxglove_bridge',
            name='foxglove_bridge',
            condition=IfCondition(use_foxglove),
            parameters=[{
                'port': 8765,
                'max_qos_depth': 10,
            }]
        ),
        
        # rqt_graph (可选)
        # Node(
        #     package='rqt_graph',
        #     executable='rqt_graph',
        #     name='rqt_graph',
        #     condition=IfCondition(use_rqt),
        # ),
    ])
```

### 启动可视化

```bash
# 启动基础可视化
ros2 launch bringup viz.launch.py

# 只启动 Foxglove（适合远程）
ros2 launch bringup viz.launch.py use_rviz:=false use_foxglove:=true

# 启动所有
ros2 launch bringup viz.launch.py use_rqt:=true
```

---

## 📊 常用可视化场景

### 场景 1: 调试 AGV
```bash
# 终端 1: 启动 AGV
ros2 launch bringup robot.launch.py

# 终端 2: 启动 RViz
rviz2
# 添加 TF、RobotModel、/cmd_vel 显示
```

### 场景 2: 监控 CAN 数据
```bash
# 使用 rqt_topic 查看原始数据
ros2 run rqt_topic rqt_topic

# 或使用 PlotJuggler 绘制曲线
ros2 run plotjuggler plotjuggler
# 然后订阅 /vehicle/state 话题
```

### 场景 3: 远程监控（无显示器）
```bash
# 在 Jetson 上
ros2 launch bringup robot.launch.py
ros2 launch bringup viz.launch.py use_rviz:=false use_foxglove:=true

# 在本地电脑浏览器打开 https://studio.foxglove.dev
# 连接 Jetson IP:8765
```

---

## 💡 建议

| 场景 | 推荐工具 | 原因 |
|------|----------|------|
| 调试机器人模型 | RViz2 | 3D 显示最直观 |
| 查看节点关系 | rqt_graph | 一目了然 |
| 监控数据流 | rqt_topic | 实时查看所有话题 |
| 分析传感器数据 | PlotJuggler | 专业的数据绘图 |
| 远程无显示器 | Foxglove | Web 界面，跨平台 |
| 调整参数 | rqt_reconfigure | 实时修改，立即生效 |
