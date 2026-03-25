# AGV 安全测试控制面板使用说明

## 概述

这是一个专门为AGV（YUHESEN FW-Max）设计的安全测试控制界面，使用**按钮控制**方式，按住移动，松开停止，适合小范围安全测试。

## 文件位置

```
web_dashboard/agv_test_control.html
```

## 启动步骤

### 1. 配置CAN接口

```bash
cd ~/Blueberry_s4
sudo ./scripts/s4 can auto
```

### 2. 启动ROS2节点

```bash
# 加载环境
source install/setup.bash

# 启动AGV驱动
ros2 launch bringup robot.launch.py
```

### 3. 启动rosbridge（用于WebSocket连接）

```bash
# 在新终端中
source /opt/ros/humble/setup.bash
ros2 launch rosbridge_server rosbridge_websocket_launch.xml
```

默认WebSocket端口是9090，如果你的配置不同，请在界面中修改URL。

### 4. 打开测试控制面板

```bash
# 使用浏览器打开
firefox web_dashboard/agv_test_control.html
# 或
chromium web_dashboard/agv_test_control.html
```

或者使用Python简单HTTP服务器：

```bash
cd web_dashboard
python3 -m http.server 8080
# 然后在浏览器中访问 http://localhost:8080/agv_test_control.html
```

## 控制说明

### 档位模式

1. **4T4D模式 (档位06)**：四转四驱模式
   - ▲ 前进：X轴正方向移动
   - ▼ 后退：X轴负方向移动
   - ◀ 左转：原地逆时针旋转
   - ▶ 右转：原地顺时针旋转

2. **横移模式 (档位08)**：平移模式
   - ▲ 前进：X轴正方向移动
   - ▼ 后退：X轴负方向移动
   - ◀ 左移：Y轴正方向平移
   - ▶ 右移：Y轴负方向平移

### 速度设置

- **X轴速度**：前后移动速度（默认0.05 m/s，最大0.5 m/s）
- **Y轴速度**：左右平移速度（默认0.05 m/s，最大0.3 m/s）
- **Z轴速度**：旋转速度（默认10°/s，最大30°/s）

### 操作方式

1. **鼠标/触摸**：按住方向按钮移动，松开停止
2. **键盘**：
   - W/↑：前进
   - S/↓：后退
   - A/←：左转/左移
   - D/→：右转/右移
   - 空格/Esc：停止

## 安全提示

⚠️ **测试前请确保：**

1. AGV周围1米内无障碍物
2. 地面平整，无滑坡风险
3. 从最小速度（0.05 m/s）开始测试
4. 随时准备按**紧急停止**按钮
5. 测试时人员站在安全位置

## 工作原理

根据YUHESEN CAN协议：

- **CAN ID**: 0x18C4D1D0 (ctrl_cmd)
- **周期**: 10ms (控制面板以100Hz频率发送)
- **协议格式**: 
  - Byte0[3:0] = 档位
  - X轴线速度 = 0.001 m/s/bit
  - Y轴线速度 = 0.001 m/s/bit (仅在横移档有效)
  - Z轴角速度 = 0.01 °/s/bit

## 故障排除

### 连接失败
- 检查rosbridge是否启动：`ros2 node list` 查看 `/rosbridge_websocket`
- 检查WebSocket URL是否正确（默认ws://localhost:9090或ws://localhost:9091）

### 点击按钮无反应
- 检查CAN接口：`ip link show can2`
- 检查AGV节点是否运行：`ros2 topic list | grep ctrl_cmd`
- 检查解锁序列是否成功（查看日志）

### 车辆不移动
- 确认已发送解锁序列（连接后自动发送）
- 检查档位是否正确（4T4D或横移）
- 查看ROS日志：`ros2 topic echo /chassis_info_fb`

## 与原始控制面板的区别

| 特性 | agv_test_control.html | index.html |
|------|----------------------|------------|
| 控制方式 | 按钮（按住移动） | 滑块（持续发送） |
| 速度范围 | 0.01-0.5 m/s | -2.0~2.0 m/s |
| 安全等级 | 更高 | 一般 |
| 适用场景 | 初次测试/安全测试 | 常规操作 |

## 建议测试流程

1. **首次测试**：
   ```
   速度设置: 0.05 m/s
   档位: 4T4D模式
   操作: 短按前进按钮，观察车辆反应
   ```

2. **逐步增加**：
   ```
   如果0.05 m/s正常，逐步增加到0.1 m/s、0.2 m/s
   ```

3. **测试横移**：
   ```
   切换到横移模式，测试左右平移功能
   ```

4. **停止测试**：
   ```
   松开按钮，确认车辆立即停止
   按下紧急停止，确认车辆停止
   ```
