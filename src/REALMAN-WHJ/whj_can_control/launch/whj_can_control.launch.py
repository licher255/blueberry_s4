from launch import LaunchDescription
from launch_ros.actions import Node
from launch.substitutions import LaunchConfiguration
from launch.actions import DeclareLaunchArgument


def generate_launch_description():
    return LaunchDescription([
        DeclareLaunchArgument(
            'can_name',
            default_value='can_fd',
            description='CAN interface name for WHJ (e.g. can_fd, can2)'),
        DeclareLaunchArgument(
            'motor_id',
            default_value='7',
            description='WHJ motor CAN ID'),
        DeclareLaunchArgument(
            'state_publish_rate',
            default_value='10.0',
            description='State publish rate in Hz'),
        DeclareLaunchArgument(
            'timeout_ms',
            default_value='1500',
            description='Command response timeout in ms'),
        DeclareLaunchArgument(
            'retry_count',
            default_value='5',
            description='Command retry count'),

        Node(
            package='whj_can_control',
            executable='whj_can_control_node',
            name='whj_can_control_node',
            output='screen',
            parameters=[{
                'can_name': LaunchConfiguration('can_name'),
                'motor_id': LaunchConfiguration('motor_id'),
                'state_publish_rate': LaunchConfiguration('state_publish_rate'),
                'timeout_ms': LaunchConfiguration('timeout_ms'),
                'retry_count': LaunchConfiguration('retry_count'),
            }],
        ),
    ])
