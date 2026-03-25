# Web Dashboard 使用指南

Blueberry S4 的轻量级 Web 监控仪表盘，通过浏览器实时查看机器人状态。

## 功能特性

- 📡 **实时话题监控** - 查看所有 ROS2 话题
- 🚗 **车辆状态** - 速度、转向角、电压、电流
- 📝 **系统日志** - 实时显示连接状态
- 🎨 **深色主题** - 适合工业环境使用

## 快速开始

### 1. 启动 Web Dashboard

```bash
cd ~/Blueberry_s4
bash web_dashboard/start_web_dashboard.sh
```

或手动启动：

```bash
# 终端 1: 启动 HTTP 服务器
cd web_dashboard
python3 -m http.server 8080

# 终端 2: 启动 ROS2 Bridge
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9091
```

### 2. 访问仪表盘

在浏览器中打开：

```
http://<jetson-ip>:8080
```

例如：`http://192.168.1.100:8080`

### 3. 连接 ROS2

点击页面上的 **"Connect"** 按钮，即可看到实时数据。

## 界面说明

| 区域 | 说明 |
|------|------|
| 连接状态 | 显示 WebSocket 连接状态 |
| 车辆状态 | 速度、转向角、电压、电流 |
| ROS2 话题 | 当前活跃的话题列表 |
| 系统日志 | 连接和数据接收日志 |

## 配置

### 修改 WebSocket 地址

默认连接 `ws://localhost:9091`，如需修改：

1. 编辑 `index.html` 第 158 行：
```html
<input type="text" id="ws-url" value="ws://your-ip:9091">
```

2. 或在页面上直接修改输入框

### 修改端口号

如果 9091 端口被占用：

```bash
# 使用 9092 端口
ros2 launch rosbridge_server rosbridge_websocket_launch.xml port:=9092
```

然后修改 `index.html` 中的默认地址。

## 故障排除

### 无法连接

1. **检查服务是否运行**
   ```bash
   lsof -i :8080   # HTTP 服务器
   lsof -i :9091   # ROS2 Bridge
   ```

2. **检查防火墙**
   ```bash
   sudo ufw allow 8080/tcp
   sudo ufw allow 9091/tcp
   ```

3. **检查 ROS2 环境**
   ```bash
   ros2 topic list  # 确保节点在运行
   ```

### 页面显示但无数据

- 确认机器人已启动：`./scripts/s4 status`
- 确认 WebSocket 地址正确
- 检查浏览器控制台（F12）查看错误信息

## 技术说明

- **前端**: 纯 HTML + JavaScript，无需构建
- **通信**: WebSocket (rosbridge_server)
- **协议**: rosbridge v2.0

## 相关文档

- [远程访问指南](../docs/deployment/remote_access_guide.md)
- [Foxglove Studio](https://studio.foxglove.dev) - 高级可视化工具
