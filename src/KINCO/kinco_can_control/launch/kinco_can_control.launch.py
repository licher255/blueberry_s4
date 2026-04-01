from launch import LaunchDescription
from launch_ros.actions import Node
from launch.substitutions import LaunchConfiguration
from launch.actions import DeclareLaunchArgument


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument(
            'can_name',
            default_value='can3',
            description='CAN interface name (e.g., can3 for PEAK PCAN, can_fd for ZLG)'),
        DeclareLaunchArgument(
            'node_id',
            default_value='1',
            description='Kinco CANopen node ID'),
        DeclareLaunchArgument(
            'state_publish_rate',
            default_value='10.0',
            description='State publish rate in Hz'),

        Node(
            package='kinco_can_control',
            executable='kinco_can_control_node',
            name='kinco_can_control_node',
            output='screen',
            parameters=[{
                'can_name': LaunchConfiguration('can_name'),
                'node_id': LaunchConfiguration('node_id'),
                'state_publish_rate': LaunchConfiguration('state_publish_rate'),
            }],
        ),
    ])
