# S4 项目 - 远程访问指南

## 🎯 方案概览

由于 Jetson 不接显示器，我们使用 **Foxglove Studio** 进行远程可视化。

```
┌─────────────────┐      WebSocket       ┌─────────────────┐
│   你的电脑       │ ◄──────────────────► │   Jetson        │
│  (浏览器)        │    ws://jetson:8765  │  (Foxglove      │
│                 │                      │   Bridge)       │
│  Foxglove       │                      │                 │
│  Studio         │                      │  ROS2 节点      │
└─────────────────┘                      └─────────────────┘
```

---

## 📋 前置条件

1. **Jetson 和你的电脑在同一网络**（或 Jetson 有公网 IP）
2. **知道 Jetson 的 IP 地址**
3. **防火墙允许 8765 端口**（部署脚本会自动配置）

---

## 🚀 快速开始

### 1. 在 Jetson 上部署（已完成）

```bash
bash scripts/deploy_to_jetson.sh
# 选择安装可视化工具
```

### 2. 在 Jetson 上启动 Foxglove Bridge

```bash
source ~/s4_ws/start_s4.sh

# 启动 Foxglove Bridge
ros2 launch foxglove_bridge foxglove_bridge_launch.xml

# 或自定义端口
ros2 launch foxglove_bridge foxglove_bridge_launch.xml port:=8765
```

你会看到：
```
[FoxgloveBridge]: WebSocket server running at ws://0.0.0.0:8765
```

### 3. 在你的电脑上访问

打开浏览器，访问：
```
https://studio.foxglove.dev
```

然后：
1. 点击 "Open connection"
2. 选择 "Foxglove WebSocket"
3. 输入地址：`ws://<jetson-ip>:8765`
   - 例如：`ws://192.168.1.100:8765`
4. 点击 "Open"

🎉 现在你可以在浏览器中看到 Jetson 上的 ROS2 数据了！

---

## 🔧 详细配置

### Jetson IP 地址

在 Jetson 上查看 IP：
```bash
ip addr show | grep "inet " | head -3
```

通常是：
- WiFi: `192.168.1.xxx` (wlan0)
- 以太网: `10.0.0.xxx` 或 `192.168.1.xxx` (eth0)

### 防火墙配置

如果连接失败，检查防火墙：

```bash
# 在 Jetson 上
sudo ufw status  # 查看防火墙状态

# 如果 8765 端口被阻止，打开它
sudo ufw allow 8765/tcp

# 或者临时关闭防火墙（仅测试）
sudo ufw disable
```

### 端口转发（如果从外网访问）

如果 Jetson 在路由器后面，需要配置端口转发：
1. 登录路由器管理界面
2. 找到 "端口转发" 或 "Port Forwarding"
3. 添加规则：外部端口 8765 → Jetson IP:8765

---

## 📊 Foxglove 界面配置

### 添加面板

在 Foxglove Studio 中，你可以添加各种面板：

| 面板 | 用途 | 配置 |
|------|------|------|
| **3D** | 显示机器人、点云、路径 | Topic: `/tf`, `/scan` |
| **Image** | 显示相机图像 | Topic: `/camera/color/image_raw` |
| **Plot** | 绘制数据曲线 | Topic: `/vehicle/state` |
| **Log** | 查看日志 | Topic: `/rosout` |
| **Raw Messages** | 查看原始消息 | 选择任意话题 |
| **Teleop** | 虚拟遥控器 | Topic: `/cmd_vel` |

### 保存布局

配置好面板后：
1. File → Save Layout
2. 保存为 `s4_layout.json`
3. 下次直接加载

---

## 🎮 启动脚本（一键启动）

创建 `~/s4_ws/start_remote_viz.sh`：

```bash
#!/bin/bash
# 一键启动远程可视化

echo "🚀 启动 S4 远程可视化..."
echo ""

# 加载环境
export ROS_DOMAIN_ID=42
source ~/s4_ws/install/setup.bash

# 获取 IP 地址
IP=$(ip route get 1 | awk '{print $7; exit}')
echo "📡 Jetson IP: $IP"
echo ""

# 检查 Foxglove Bridge
if ! ros2 pkg list | grep -q foxglove_bridge; then
    echo "❌ Foxglove Bridge 未安装"
    echo "   安装: sudo apt install ros-humble-foxglove-bridge"
    exit 1
fi

echo "🌐 启动 Foxglove Bridge..."
echo "   地址: ws://$IP:8765"
echo ""
echo "💻 在你的电脑上:"
echo "   1. 打开 https://studio.foxglove.dev"
echo "   2. 选择 'Open connection'"
echo "   3. 输入: ws://$IP:8765"
echo ""

# 启动 Bridge
ros2 launch foxglove_bridge foxglove_bridge_launch.xml
```

使用：
```bash
chmod +x ~/s4_ws/start_remote_viz.sh
~/s4_ws/start_remote_viz.sh
```

---

## 🔐 安全建议

### 内网使用（推荐）

确保 Jetson 和你的电脑在同一内网，不暴露到公网。

### 公网访问（如果需要）

如果必须从外网访问：

1. **使用 SSH 隧道**（安全）
   ```bash
   # 在你的电脑上
   ssh -L 8765:localhost:8765 hkclr@<jetson-ip>
   
   # 然后浏览器访问 ws://localhost:8765
   ```

2. **启用认证**（Foxglove 支持）
   ```bash
   # 启动时添加认证参数
   ros2 launch foxglove_bridge foxglove_bridge_launch.xml \
     port:=8765 \
     tls:=true \
     certfile:=/path/to/cert.pem \
     keyfile:=/path/to/key.pem
   ```

3. **限制 IP 访问**
   ```bash
   # 使用防火墙只允许特定 IP
   sudo ufw allow from <your-ip> to any port 8765
   ```

---

## 🐛 故障排除

### 问题 1: 连接失败

**症状**：Foxglove 显示 "Connection failed"

**排查**：
```bash
# 在 Jetson 上测试端口
netstat -tlnp | grep 8765

# 应该显示 LISTEN 状态
# 如果没有，Bridge 没启动成功

# 测试本地连接
curl http://localhost:8765
# 应该返回 WebSocket 握手错误（这是正常的）
```

**解决**：
- 确认 Bridge 已启动
- 检查防火墙 `sudo ufw allow 8765/tcp`
- 确认 IP 地址正确

### 问题 2: 没有数据显示

**症状**：连接成功，但面板空白

**排查**：
```bash
# 在 Jetson 上检查话题
ros2 topic list

# 确认有数据发布
ros2 topic echo /tf
```

**解决**：
- 确保 ROS2 节点已启动
- 检查话题名称是否正确
- 确认 ROS_DOMAIN_ID 一致

### 问题 3: 延迟高

**症状**：画面卡顿，延迟几秒

**解决**：
- 使用有线网络代替 WiFi
- 降低数据发布频率
- 只订阅必要的话题

---

## 📱 移动端访问

Foxglove Studio 支持移动端浏览器，可以用手机/平板查看：
1. 确保手机和 Jetson 在同一 WiFi
2. 手机浏览器访问 https://studio.foxglove.dev
3. 输入 Jetson IP:8765

---

## 🎯 推荐工作流程

### 日常开发

```bash
# 终端 1: SSH 到 Jetson，启动 S4
ssh hkclr@<jetson-ip>
source ~/s4_ws/start_s4.sh
ros2 launch bringup robot.launch.py

# 终端 2: SSH 到 Jetson，启动 Foxglove
ssh hkclr@<jetson-ip>
source ~/s4_ws/start_s4.sh
ros2 launch foxglove_bridge foxglove_bridge_launch.xml

# 浏览器: 打开 Foxglove Studio
# https://studio.foxglove.dev → ws://<jetson-ip>:8765
```

### 调试模式

```bash
# 一键启动远程调试
~/s4_ws/start_remote_viz.sh
```

---

## 📚 参考

- [Foxglove 官方文档](https://docs.foxglove.dev/)
- [Foxglove Bridge 参数](https://github.com/foxglove/ros-foxglove-bridge)
