#!/usr/bin/env python3
"""
Blueberry S4 - 配置加载工具
简单的 YAML 配置读取，不依赖 ROS2
"""

import yaml
import os
from typing import Dict, Any, Optional
from dataclasses import dataclass


@dataclass
class CANInterface:
    """CAN 接口配置"""
    name: str
    device: str
    type: str
    bitrate: int
    dbitrate: int = 0
    

@dataclass  
class Device:
    """设备配置"""
    name: str
    manufacturer: str
    enabled: bool
    can_interface: Optional[str]


class HardwareConfig:
    """硬件配置管理器"""
    
    def __init__(self, config_path: str = None):
        """
        加载配置文件
        
        Args:
            config_path: 配置文件路径，默认读取 config/hardware_profile.yaml
        """
        if config_path is None:
            # 自动查找配置文件
            script_dir = os.path.dirname(os.path.abspath(__file__))
            config_path = os.path.join(script_dir, "hardware_profile.yaml")
        
        self.config_path = config_path
        self.config = self._load_yaml()
        
    def _load_yaml(self) -> Dict[str, Any]:
        """读取 YAML 文件"""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            raise FileNotFoundError(f"配置文件不存在: {self.config_path}")
        except yaml.YAMLError as e:
            raise ValueError(f"YAML 格式错误: {e}")
    
    # ==================== CAN 接口操作 ====================
    
    def get_can_interfaces(self) -> list:
        """获取所有 CAN 接口配置"""
        return self.config.get('can_interfaces', [])
    
    def get_can_interface(self, name: str) -> Optional[Dict]:
        """获取指定 CAN 接口配置"""
        for iface in self.get_can_interfaces():
            if iface['name'] == name:
                return iface
        return None
    
    def get_can_setup_commands(self) -> list:
        """
        生成 CAN 接口初始化命令
        
        Returns:
            list of (device, command) tuples
        """
        commands = []
        for iface in self.get_can_interfaces():
            device = iface['device']
            bitrate = iface['bitrate']
            
            if iface['type'] == 'canfd':
                # CAN-FD 配置
                dbitrate = iface.get('dbitrate', 5000000)
                cmd = f"ip link set {device} up type can bitrate {bitrate} dbitrate {dbitrate} fd on"
            else:
                # 普通 CAN 配置
                cmd = f"ip link set {device} up type can bitrate {bitrate}"
            
            commands.append((device, cmd))
        return commands
    
    # ==================== 设备操作 ====================
    
    def get_device(self, name: str) -> Optional[Dict]:
        """获取指定设备配置"""
        return self.config.get('devices', {}).get(name)
    
    def get_enabled_devices(self) -> Dict[str, Dict]:
        """获取所有启用的设备"""
        devices = {}
        for name, config in self.config.get('devices', {}).items():
            if config.get('enabled', False):
                devices[name] = config
        return devices
    
    def get_device_can_mapping(self) -> Dict[str, str]:
        """
        获取设备到 CAN 接口的映射
        
        Returns:
            {device_name: can_interface_name}
        """
        mapping = {}
        for name, config in self.get_enabled_devices().items():
            can_iface = config.get('can_interface')
            if can_iface:
                mapping[name] = can_iface
        return mapping
    
    # ==================== 相机和雷达 ====================
    
    def get_camera_config(self) -> Dict:
        """获取相机配置"""
        return self.config.get('cameras', {})
    
    def get_lidar_config(self) -> Dict:
        """获取雷达配置"""
        return self.config.get('lidar', {})
    
    # ==================== 调试配置 ====================
    
    def is_simulation(self) -> bool:
        """检查是否处于仿真模式"""
        return self.config.get('debug', {}).get('simulation', {}).get('enabled', False)
    
    def is_can_debug(self) -> bool:
        """检查是否启用 CAN 调试"""
        return self.config.get('debug', {}).get('can_debug', {}).get('enabled', False)


# ==================== 命令行工具 ====================

def print_setup_info():
    """打印系统配置信息"""
    config = HardwareConfig()
    
    print("=" * 60)
    print("Blueberry S4 - 硬件配置信息")
    print("=" * 60)
    
    # CAN 接口
    print("\n📡 CAN 接口配置:")
    for iface in config.get_can_interfaces():
        print(f"  • {iface['name']}:")
        print(f"    设备: {iface['device']}")
        print(f"    类型: {iface['type'].upper()}")
        print(f"    波特率: {iface['bitrate'] // 1000}K")
        if iface['type'] == 'canfd':
            print(f"    数据段: {iface.get('dbitrate', 0) // 1000}K")
    
    # CAN 初始化命令
    print("\n🔧 CAN 初始化命令:")
    for device, cmd in config.get_can_setup_commands():
        print(f"  sudo {cmd}")
    
    # 设备列表
    print("\n🔌 已启用设备:")
    for name, dev in config.get_enabled_devices().items():
        can_info = f" -> {dev.get('can_interface', 'N/A')}" if dev.get('can_interface') else ""
        print(f"  • {dev['name']} ({dev['manufacturer']}){can_info}")
    
    # 设备-CAN 映射
    print("\n🔗 设备-CAN 映射:")
    mapping = config.get_device_can_mapping()
    for device, can_iface in mapping.items():
        print(f"  {device} -> {can_iface}")
    
    # 传感器
    cameras = config.get_camera_config()
    if cameras.get('enabled'):
        d405 = cameras.get('d405_array', {})
        print(f"\n📷 相机: {d405.get('count', 0)}x D405")
    
    lidar = config.get_lidar_config()
    if lidar.get('enabled'):
        print(f"\n🔍 雷达: {lidar.get('name', 'Unknown')}")
    
    # 调试模式
    if config.is_simulation():
        print("\n⚠️  仿真模式已启用 (无真实硬件)")
    
    print("\n" + "=" * 60)


def generate_setup_script():
    """生成 CAN 初始化脚本"""
    config = HardwareConfig()
    
    script = """#!/bin/bash
# Blueberry S4 - CAN 初始化脚本
# 自动生成，请勿手动修改

echo "🚀 配置 CAN 接口..."

# 加载内核模块
sudo modprobe can
sudo modprobe can_raw

"""
    
    for device, cmd in config.get_can_setup_commands():
        script += f"""
echo "配置 {device}..."
sudo {cmd}
"""
    
    script += """
# 验证配置
echo ""
echo "✅ CAN 接口状态:"
ip link show | grep -E "can[0-9]"

echo ""
echo "🎉 CAN 配置完成!"
"""
    
    output_path = "/tmp/setup_can.sh"
    with open(output_path, 'w') as f:
        f.write(script)
    os.chmod(output_path, 0o755)
    
    print(f"✅ 初始化脚本已生成: {output_path}")
    print(f"   运行: sudo {output_path}")


if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "--script":
        generate_setup_script()
    else:
        print_setup_info()
