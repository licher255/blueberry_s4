from launch import LaunchDescription
from launch_ros.actions import Node
from launch.substitutions import LaunchConfiguration
from launch.actions import DeclareLaunchArgument
from ament_index_python.packages import get_package_share_directory
import os

def generate_launch_description():
    # Get package path
    pkg_path = get_package_share_directory('whj_can_control')
    
    # Declare launch arguments
    can_interface_arg = DeclareLaunchArgument(
        'can_interface',
        default_value='can1',
        description='CAN interface name for WHJ'
    )
    
    canfd_enabled_arg = DeclareLaunchArgument(
        'canfd_enabled',
        default_value='true',
        description='Enable CAN-FD mode'
    )
    
    # Config file path
    config_file = os.path.join(pkg_path, 'params', 'whj_config.yaml')
    
    # WHJ CAN control node
    whj_node = Node(
        package='whj_can_control',
        executable='whj_can_control_node',
        name='whj_can_control_node',
        output='screen',
        parameters=[
            config_file,
            {
                'can_name': LaunchConfiguration('can_interface'),
                'canfd_enabled': LaunchConfiguration('canfd_enabled'),
            }
        ],
        arguments=['--ros-args', '--log-level', 'info']
    )
    
    return LaunchDescription([
        can_interface_arg,
        canfd_enabled_arg,
        whj_node,
    ])
