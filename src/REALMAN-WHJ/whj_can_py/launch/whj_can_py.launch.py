#!/usr/bin/env python3
"""
Launch file for WHJ Python CAN node

Usage:
    ros2 launch whj_can_py whj_can_py.launch.py
    ros2 launch whj_can_py whj_can_py.launch.py can_interface:=can2 motor_id:=7
"""

from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node


def generate_launch_description():
    # Launch arguments
    can_interface_arg = DeclareLaunchArgument(
        'can_interface',
        default_value='can_fd',
        description='SocketCAN interface name (e.g., can0, can_fd, can2)'
    )
    
    motor_id_arg = DeclareLaunchArgument(
        'motor_id',
        default_value='7',
        description='WHJ motor ID (1-30)'
    )
    
    state_publish_rate_arg = DeclareLaunchArgument(
        'state_publish_rate',
        default_value='10.0',
        description='State publish rate in Hz'
    )
    
    auto_enable_arg = DeclareLaunchArgument(
        'auto_enable',
        default_value='true',
        description='Auto-enable motor on startup'
    )
    
    max_velocity_arg = DeclareLaunchArgument(
        'max_velocity',
        default_value='1000.0',
        description='Maximum velocity for trajectory planning [degrees/s]'
    )
    
    max_acceleration_arg = DeclareLaunchArgument(
        'max_acceleration',
        default_value='2000.0',
        description='Maximum acceleration for trajectory planning [degrees/s^2]'
    )
    
    # Node
    # Note: For ament_python packages, the executable is installed to bin/
    # We use the full path via 'exec' in parameters or just rely on PATH
    whj_node = Node(
        package='whj_can_py',
        executable='whj_can_node',
        name='whj_can_py_node',
        output='screen',
        emulate_tty=True,
        parameters=[{
            'can_interface': LaunchConfiguration('can_interface'),
            'motor_id': LaunchConfiguration('motor_id'),
            'state_publish_rate': LaunchConfiguration('state_publish_rate'),
            'auto_enable': LaunchConfiguration('auto_enable'),
            'max_velocity': LaunchConfiguration('max_velocity'),
            'max_acceleration': LaunchConfiguration('max_acceleration'),
        }],
        arguments=['--ros-args', '--log-level', 'info']
    )
    
    return LaunchDescription([
        can_interface_arg,
        motor_id_arg,
        state_publish_rate_arg,
        auto_enable_arg,
        max_velocity_arg,
        max_acceleration_arg,
        whj_node,
    ])
