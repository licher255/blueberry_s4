#!/usr/bin/env python3
"""
Test script for YUHESEN FW-Max vehicle control.

IMPORTANT Prerequisites:
1. Remote control SWA switch must be in DOWN position (instruction control mode)
2. Vehicle must be powered on and CAN bus connected
3. ROS2 CAN node must be running

Usage:
    # Terminal 1: Start ROS2 CAN node
    ros2 run yhs_can_control yhs_can_control_node
    
    # Terminal 2: Run this test
    python3 test_vehicle_control.py
"""

import rclpy
from rclpy.node import Node
from yhs_can_interfaces.msg import IoCmd, CtrlCmd
import time

class VehicleTest(Node):
    def __init__(self):
        super().__init__('vehicle_test')
        
        # Publishers
        self.io_cmd_pub = self.create_publisher(IoCmd, 'io_cmd', 10)
        self.ctrl_cmd_pub = self.create_publisher(CtrlCmd, 'ctrl_cmd', 10)
        
        # Timer for continuous command publishing (10Hz)
        self.timer = self.create_timer(0.1, self.timer_callback)
        
        # State
        self.phase = 'unlock'  # 'unlock', 'idle', 'forward', 'rotate', 'stop'
        self.phase_start_time = time.time()
        self.sequence_step = 0
        
        self.get_logger().info('Vehicle Test Node Started')
        self.get_logger().info('Make sure remote control SWA switch is in DOWN position!')
        
    def timer_callback(self):
        now = time.time()
        elapsed = now - self.phase_start_time
        
        # Create messages
        io_cmd = IoCmd()
        ctrl_cmd = CtrlCmd()
        
        if self.phase == 'unlock':
            # Phase 1: Send unlock sequence with 20ms intervals
            # Sequence: 0x02 -> 0x02 -> 0x00 -> 0x00 (per protocol)
            if self.sequence_step < 4:
                io_cmd.io_cmd_unlock = (self.sequence_step < 2)  # Steps 0,1: unlock ON
                io_cmd.io_cmd_lamp_ctrl = True  # Keep lamp on during unlock
                
                self.get_logger().info(f'Unlock sequence step {self.sequence_step}: unlock={io_cmd.io_cmd_unlock}')
                self.sequence_step += 1
                
                # Short delay between unlock frames (20ms)
                if self.sequence_step >= 4:
                    self.phase = 'idle'
                    self.phase_start_time = now
                    self.get_logger().info('Unlock sequence complete, entering idle phase')
            
        elif self.phase == 'idle':
            # Phase 2: Idle for 1 second
            io_cmd.io_cmd_unlock = True  # Keep unlocked
            io_cmd.io_cmd_lamp_ctrl = True
            ctrl_cmd.ctrl_cmd_gear = 6   # 4T4D mode
            ctrl_cmd.ctrl_cmd_x_linear = 0.0
            ctrl_cmd.ctrl_cmd_z_angular = 0.0
            
            if elapsed > 1.0:
                self.phase = 'forward'
                self.phase_start_time = now
                self.get_logger().info('Starting forward movement')
                
        elif self.phase == 'forward':
            # Phase 3: Move forward at 0.3 m/s for 3 seconds
            io_cmd.io_cmd_unlock = True
            io_cmd.io_cmd_lamp_ctrl = True
            ctrl_cmd.ctrl_cmd_gear = 6       # 4T4D mode
            ctrl_cmd.ctrl_cmd_x_linear = 0.3  # 0.3 m/s forward
            ctrl_cmd.ctrl_cmd_z_angular = 0.0
            
            if elapsed > 3.0:
                self.phase = 'rotate'
                self.phase_start_time = now
                self.get_logger().info('Starting rotation')
                
        elif self.phase == 'rotate':
            # Phase 4: Rotate in place for 3 seconds
            # Z angular: positive = counter-clockwise, negative = clockwise
            io_cmd.io_cmd_unlock = True
            io_cmd.io_cmd_lamp_ctrl = True
            ctrl_cmd.ctrl_cmd_gear = 6        # 4T4D mode
            ctrl_cmd.ctrl_cmd_x_linear = 0.0
            ctrl_cmd.ctrl_cmd_z_angular = 0.5  # Rotate CCW at 0.5 rad/s (approx 28.6 deg/s)
            
            if elapsed > 3.0:
                self.phase = 'stop'
                self.phase_start_time = now
                self.get_logger().info('Stopping')
                
        elif self.phase == 'stop':
            # Phase 5: Stop
            io_cmd.io_cmd_unlock = True
            io_cmd.io_cmd_lamp_ctrl = True
            ctrl_cmd.ctrl_cmd_gear = 6
            ctrl_cmd.ctrl_cmd_x_linear = 0.0
            ctrl_cmd.ctrl_cmd_z_angular = 0.0
            
            if elapsed > 1.0:
                self.get_logger().info('Test complete')
                return
        
        # Publish commands
        self.io_cmd_pub.publish(io_cmd)
        if self.phase not in ['unlock']:
            self.ctrl_cmd_pub.publish(ctrl_cmd)

def main(args=None):
    rclpy.init(args=args)
    node = VehicleTest()
    
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
