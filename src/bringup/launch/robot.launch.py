#!/usr/bin/env python3
"""
S4 - 主启动文件
启动所有硬件节点和算法
支持动态CAN接口映射
"""

import os
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription, LogInfo
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution, TextSubstitution
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.substitutions import FindPackageShare
from launch_ros.actions import Node


def get_can_interface(driver_type, default_iface):
    """从缓存文件读取CAN接口映射"""
    cache_file = f"/tmp/can_{driver_type}.iface"
    try:
        if os.path.exists(cache_file):
            with open(cache_file, 'r') as f:
                iface = f.read().strip()
                if iface:
                    return iface
    except Exception:
        pass
    return default_iface


def generate_launch_description():
    """生成启动描述"""
    
    # ==================== 动态CAN接口检测 ====================
    # 从 /tmp/can_*.iface 缓存文件读取接口映射
    agv_can_iface = get_can_interface('pcan', 'can3')  # AGV使用pcan
    devices_can_iface = get_can_interface('usbcanfd', 'can1')  # WHJ/Kinco使用usbcanfd
    
    # ==================== 启动参数 ====================
    
    # 仿真模式
    sim_arg = DeclareLaunchArgument(
        'sim',
        default_value='false',
        description='Enable simulation mode (no real hardware)'
    )
    
    # 启用的硬件
    use_agv_arg = DeclareLaunchArgument(
        'use_agv',
        default_value='true',
        description='Enable AGV (YUHESEN FW-Max)'
    )
    
    use_whj_arg = DeclareLaunchArgument(
        'use_whj',
        default_value='false',  # 默认禁用，需要硬件连接
        description='Enable WHJ lifter'
    )
    
    use_kinco_arg = DeclareLaunchArgument(
        'use_kinco',
        default_value='false',  # 默认禁用，需要硬件连接
        description='Enable Kinco servo'
    )
    
    use_cameras_arg = DeclareLaunchArgument(
        'use_cameras',
        default_value='false',
        description='Enable D405 camera array'
    )
    
    use_lidar_arg = DeclareLaunchArgument(
        'use_lidar',
        default_value='false',
        description='Enable Livox lidar'
    )
    
    # CAN 接口配置（支持动态检测或手动覆盖）
    can_agv_arg = DeclareLaunchArgument(
        'can_agv_interface',
        default_value=agv_can_iface,  # 动态检测或默认
        description=f'CAN interface for AGV (detected: {agv_can_iface})'
    )
    
    can_devices_arg = DeclareLaunchArgument(
        'can_devices_interface',
        default_value=devices_can_iface,  # 动态检测或默认
        description=f'CAN interface for other devices (detected: {devices_can_iface})'
    )
    
    # ==================== 获取参数值 ====================
    
    sim = LaunchConfiguration('sim')
    use_agv = LaunchConfiguration('use_agv')
    use_whj = LaunchConfiguration('use_whj')
    use_kinco = LaunchConfiguration('use_kinco')
    use_cameras = LaunchConfiguration('use_cameras')
    use_lidar = LaunchConfiguration('use_lidar')
    can_agv_interface = LaunchConfiguration('can_agv_interface')
    can_devices_interface = LaunchConfiguration('can_devices_interface')
    
    # ==================== 节点定义 ====================
    
    # AGV 节点 (YUHESEN FW-Max) - 使用官方 C++ 驱动
    agv_node = Node(
        package='yhs_can_control',
        executable='yhs_can_control_node',
        name='agv_node',
        parameters=[{
            'can_name': can_agv_interface,
        }],
        condition=IfCondition(use_agv),
        output='screen',
    )
    
    # WHJ 升降节点
    whj_node = Node(
        package='whj_can_control',
        executable='whj_can_control_node',
        name='whj_can_control_node',
        parameters=[{
            'can_name': can_devices_interface,
            'canfd_enabled': True,
        }],
        condition=IfCondition(use_whj),
        output='screen',
    )
    
    # Kinco 伺服节点 (待开发)
    # kinco_node = Node(
    #     package='kinco_servo',
    #     executable='servo_node',
    #     name='kinco_servo',
    #     parameters=[{
    #         'can_interface': can_devices_interface,
    #         'node_id': 1,
    #     }],
    #     condition=IfCondition(use_kinco),
    #     output='screen',
    # )
    
    # 仿真模式参数（用于控制teleop）
    use_teleop_arg = DeclareLaunchArgument(
        'use_teleop',
        default_value='true',
        description='Enable keyboard teleop'
    )
    use_teleop = LaunchConfiguration('use_teleop')
    
    # ==================== 日志信息 ====================
    
    log_can_info = LogInfo(
        msg=f"[S4] CAN接口映射: AGV={agv_can_iface}, Devices={devices_can_iface}"
    )
    
    # ==================== 组装启动描述 ====================
    
    ld = LaunchDescription([
        # 日志
        log_can_info,
        
        # 参数声明
        sim_arg,
        use_agv_arg,
        use_whj_arg,
        use_kinco_arg,
        use_cameras_arg,
        use_lidar_arg,
        can_agv_arg,
        can_devices_arg,
        use_teleop_arg,
        
        # 节点
        agv_node,
        whj_node,
        # kinco_node,  # 待开发
    ])
    
    return ld
