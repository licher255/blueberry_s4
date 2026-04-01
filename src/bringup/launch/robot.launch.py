#!/usr/bin/env python3
"""
S4 - 主启动文件
启动所有硬件节点和算法
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument, IncludeLaunchDescription
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration, PathJoinSubstitution, TextSubstitution
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.substitutions import FindPackageShare
from launch_ros.actions import Node


def generate_launch_description():
    """生成启动描述"""
    
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
        default_value='true',
        description='Enable WHJ lifter'
    )
    
    use_kinco_arg = DeclareLaunchArgument(
        'use_kinco',
        default_value='true',
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
    
    # CAN 接口配置
    # 使用逻辑名：can_agv (PEAK PCAN-USB for AGV), can_fd (ZLG CANFD for WHJ+Kinco)
    # 实际映射由 s4 init 自动检测并写入 /tmp/s4_can_mapping.conf
    can_agv_arg = DeclareLaunchArgument(
        'can_agv_interface',
        default_value='can_agv',  # 逻辑名，指向 PEAK PCAN-USB
        description='CAN interface for AGV (PEAK PCAN-USB)'
    )
    
    can_devices_arg = DeclareLaunchArgument(
        'can_devices_interface',
        default_value='can_fd',   # 逻辑名，指向 ZLG CANFD
        description='CAN interface for WHJ+Kinco (ZLG CANFD)'
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
    # 注意：LaunchConfiguration 需要正确传递参数
    agv_node = Node(
        package='yhs_can_control',
        executable='yhs_can_control_node',
        name='agv_node',
        parameters=[{
            'can_name': can_agv_interface,  # 动态检测的 CAN 接口
        }],
        condition=IfCondition(use_agv),
        output='screen',
    )
    
    # WHJ 升降节点 (待开发)
    # whj_node = Node(
    #     package='realman_whj',
    #     executable='whj_node',
    #     name='whj_lifter',
    #     parameters=[{
    #         'can_interface': can_devices_interface,
    #         'node_id': 7,
    #     }],
    #     condition=IfCondition(use_whj),
    #     output='screen',
    # )
    
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
    
    # 键盘遥控节点 (待适配官方驱动)
    # teleop_node = Node(
    #     package='fw_max_can',
    #     executable='teleop_keyboard',
    #     name='teleop_keyboard',
    #     output='screen',
    #     condition=IfCondition(use_teleop),
    #     prefix='xterm -e',
    # )
    
    # ==================== 组装启动描述 ====================
    
    ld = LaunchDescription([
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
        # whj_node,  # 待开发
        # kinco_node,  # 待开发
        # teleop_node,  # 待适配官方驱动
    ])
    
    return ld
