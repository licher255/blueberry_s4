# S4 项目安全部署指南 - Jetson 环境保护

⚠️ **重要**: 本 Jetson 有其他同事的项目在运行，部署必须**零影响**！

---

## 🛡️ 部署原则

1. **不修改系统级配置** (如 `/etc/` 下的文件)
2. **不覆盖现有 ROS2 工作空间** (检查 `~/ros2_ws` 是否存在)
3. **使用独立的工作空间名称**
4. **所有改动可回滚**
5. **先测试，再部署**

---

## 📋 部署前检查清单

### 1. 检查现有环境

```bash
# 运行检查脚本
bash /home/hkclr/Blueberry_s4/scripts/jetson_precheck.sh
```

**关键检查项**:
- [ ] 现有 ROS2 工作空间位置
- [ ] 已占用的 ROS_DOMAIN_ID
- [ ] 已使用的 CAN 接口
- [ ] 已运行的 ROS2 节点
- [ ] 磁盘空间 (> 5GB 剩余)

### 2. 确认隔离方案

| 资源 | 现有项目 | S4 项目 | 隔离方式 |
|------|----------|---------|----------|
| 工作空间 | `~/ros2_ws` (假设) | `~/s4_ws` | **不同目录** |
| ROS_DOMAIN_ID | 0 (默认) | 42 | **环境变量** |
| CAN 接口 | can0 | can0/can1 | **时间隔离** |
| 网络端口 | 默认 | 自定义 | **配置隔离** |

---

## 🚀 安全部署步骤

### 步骤 1: 创建独立工作空间（推荐）

```bash
# 使用完全不同的目录，与现有项目隔离
mkdir -p ~/s4_ws/src
cd ~/s4_ws/src

# 创建符号链接（不复制，节省空间）
ln -s /home/hkclr/Blueberry_s4/src/bringup .
ln -s /home/hkclr/Blueberry_s4/src/YUHESEN-FW-MAX .

# 或复制（如果担心原项目改动）
# cp -r /home/hkclr/Blueberry_s4/src/bringup .
# cp -r /home/hkclr/Blueberry_s4/src/YUHESEN-FW-MAX .
```

**为什么这样做**:
- `~/s4_ws` 和 `~/ros2_ws` 完全独立
- 编译互不影响
- 可以随时删除 `~/s4_ws` 而不影响其他项目

### 步骤 2: 使用独立的 ROS_DOMAIN_ID

```bash
# 创建专用启动脚本
cat > ~/s4_ws/start_s4.sh << 'STARTEOF'
#!/bin/bash
# S4 项目专用启动脚本
# 使用独立的 ROS_DOMAIN_ID 避免与现有项目冲突

echo "🚀 启动 S4 项目 (ROS_DOMAIN_ID=42)..."

# 隔离配置
export ROS_DOMAIN_ID=42
export ROS_LOCALHOST_ONLY=0

# 加载 S4 工作空间
source ~/s4_ws/install/setup.bash

# 配置 CAN（如果可用）
if ip link show can0 &> /dev/null; then
    echo "📡 CAN 接口可用"
else
    echo "⚠️  CAN 接口未配置"
fi

echo ""
echo "可用命令:"
echo "  ros2 launch bringup robot.launch.py"
echo "  ros2 topic list"
echo ""

# 进入交互模式
bash
STARTEOF

chmod +x ~/s4_ws/start_s4.sh
```

**ROS_DOMAIN_ID 说明**:
- `ROS_DOMAIN_ID=0` (默认): 与所有默认项目通信
- `ROS_DOMAIN_ID=42` (S4 专用): 只与同样设置的项目通信
- 完全隔离，不会干扰现有项目

### 步骤 3: 编译（隔离环境）

```bash
cd ~/s4_ws

# 确保不会影响现有项目
unset COLCON_PREFIX_PATH
unset CMAKE_PREFIX_PATH

# 编译
colcon build --symlink-install

# 检查编译结果
echo "✅ 编译完成"
echo "工作空间: ~/s4_ws"
echo "install 目录大小:"
du -sh install/
```

### 步骤 4: 测试运行（不启动硬件）

```bash
# 1. 进入 S4 环境
source ~/s4_ws/start_s4.sh

# 2. 检查是否隔离
echo "ROS_DOMAIN_ID: $ROS_DOMAIN_ID"
ros2 topic list
# 应该看不到现有项目的话题

# 3. 测试节点启动（仿真模式）
ros2 launch bringup robot.launch.py sim:=true
```

---

## 🔧 CAN 接口安全使用

### 问题：CAN 接口可能被占用

如果现有项目在使用 `can0`，你有两个选择：

### 方案 A: 时间隔离（推荐）

与同事的**时间错开**使用：
```bash
# 检查 CAN 是否被占用
cat /proc/net/can/can0

# 如果未被占用，临时配置
sudo ip link set can0 up type can bitrate 500000

# 使用完后立即关闭
sudo ip link set can0 down
```

### 方案 B: 使用独立 CAN 接口

如果有多个 CAN 接口：
- `can0`: 现有项目使用
- `can1`: S4 项目专用

修改配置：
```bash
# ~/s4_ws/src/bringup/config/robot.yaml
can:
  agv:
    interface: "can1"  # 改为 can1
```

---

## 📊 资源监控

### 检查磁盘空间

```bash
# 确保有足够空间
df -h ~

# 清理 S4 编译缓存（如果需要）
cd ~/s4_ws
rm -rf build log
```

### 检查内存使用

```bash
# 运行前检查
free -h

# S4 项目内存占用预估
# - 基础 ROS2 节点: ~100MB
# - CAN 通信: ~50MB
# - 相机驱动 (7x D405): ~2-4GB
# - Livox 雷达: ~500MB
```

---

## 🔄 回滚方案

如果出现问题，**立即停止并回滚**：

```bash
# 1. 停止所有 S4 节点
Ctrl+C  # 在运行终端中

# 2. 关闭 CAN 接口（如果配置了）
sudo ip link set can0 down 2>/dev/null || true
sudo ip link set can1 down 2>/dev/null || true

# 3. 删除工作空间（如果需要完全移除）
rm -rf ~/s4_ws

# 4. 检查现有项目是否受影响
cd ~/ros2_ws  # 现有项目工作空间
source install/setup.bash
ros2 topic list  # 检查是否正常
```

---

## ✅ 部署后验证

### 验证 1: S4 项目独立运行

```bash
source ~/s4_ws/start_s4.sh

# 应该只看到 S4 的话题
ros2 topic list

# 测试发布os2 topic pub /test std_msgs/String "data: 'hello'" --once
```

### 验证 2: 现有项目不受影响

**在另一个终端**（不 source S4）：

```bash
# 加载现有项目
source ~/ros2_ws/install/setup.bash

# 应该看不到 S4 的话题（ROS_DOMAIN_ID 不同）
ros2 topic list

# 现有节点正常运行
ros2 node list
```

### 验证 3: CAN 接口状态

```bash
# 检查 CAN 是否被正确释放
ip link show can0
# 应该显示 DOWN（未使用）或现有项目配置
```

---

## 🚨 紧急情况处理

### 情况 1: 同事报告他们的项目受影响

```bash
# 立即停止 S4
pkill -f "ros2 launch bringup"
sudo ip link set can0 down

# 检查进程
ps aux | grep ros2

# 确认现有项目恢复
cd ~/ros2_ws && source install/setup.bash
ros2 topic list
```

### 情况 2: 磁盘空间不足

```bash
# 立即清理 S4 编译缓存
cd ~/s4_ws
rm -rf build log

# 如果还不够，删除 install
cd ~
rm -rf s4_ws
```

### 情况 3: CAN 冲突

```bash
# 查看谁在使用 CAN
sudo cat /proc/net/can/can0

# 恢复 CAN 到默认状态
sudo ip link set can0 down
sudo ip link set can0 up type can bitrate 500000  # 或其他项目的配置
```

---

## 📞 沟通清单

部署前与**同事确认**：

- [ ] CAN 接口使用时间
- [ ] 内存/CPU 占用限制
- [ ] 磁盘空间限制
- [ ] 网络端口范围
- [ ] 紧急联系方式

---

## 📝 总结

| 操作 | 命令 | 影响 |
|------|------|------|
| **检查环境** | `bash scripts/jetson_precheck.sh` | 零影响 |
| **创建隔离空间** | `mkdir ~/s4_ws` | 零影响 |
| **编译** | `colcon build` | 仅 ~/s4_ws |
| **运行** | `source start_s4.sh` | 独立进程 |
| **清理** | `rm -rf ~/s4_ws` | 完全移除 |

**关键**: 所有操作都限制在 `~/s4_ws` 目录内，绝不触碰其他项目！
