#!/usr/bin/env python3
"""
AGV 控制测试脚本 - 直接通过 ROS2 发布控制命令
用于验证 AGV 是否能正常响应控制命令

使用方法:
  python3 test_agv_control.py
"""
import rclpy
from rclpy.node import Node
from yhs_can_interfaces.msg import IoCmd, CtrlCmd
import time

class AGVTestController(Node):
    def __init__(self):
        super().__init__('agv_test_controller')
        
        # 创建发布者
        self.io_pub = self.create_publisher(IoCmd, '/io_cmd', 1)
        self.ctrl_pub = self.create_publisher(CtrlCmd, '/ctrl_cmd', 1)
        
        # 创建定时器
        self.timer = self.create_timer(0.1, self.timer_callback)  # 10Hz
        
        self.counter = 0
        self.phase = 'unlock'  # unlock -> move -> stop
        self.start_time = time.time()
        
        self.get_logger().info("AGV 测试控制器已启动")
        self.get_logger().info("阶段1: 解锁 (2秒)")
    
    def timer_callback(self):
        elapsed = time.time() - self.start_time
        
        # 阶段1: 解锁序列 (0-2秒)
        if elapsed < 2.0:
            msg = IoCmd()
            msg.io_cmd_unlock = True
            msg.io_cmd_lamp_ctrl = True
            self.io_pub.publish(msg)
            if self.counter % 10 == 0:
                self.get_logger().info(f"解锁中... ({elapsed:.1f}s)")
        
        # 阶段2: 前进 (2-5秒)
        elif elapsed < 5.0:
            if self.phase != 'move':
                self.phase = 'move'
                self.get_logger().info("阶段2: 前进 (3秒)")
            
            # 发送解锁保持
            io_msg = IoCmd()
            io_msg.io_cmd_unlock = True
            io_msg.io_cmd_lamp_ctrl = True
            self.io_pub.publish(io_msg)
            
            # 发送控制命令
            ctrl_msg = CtrlCmd()
            ctrl_msg.ctrl_cmd_gear = 6  # 4T4D档
            ctrl_msg.ctrl_cmd_x_linear = 0.1  # 0.1 m/s 前进
            ctrl_msg.ctrl_cmd_y_linear = 0.0
            ctrl_msg.ctrl_cmd_z_angular = 0.0
            self.ctrl_pub.publish(ctrl_msg)
            
            if self.counter % 10 == 0:
                self.get_logger().info(f"前进中... 速度=0.1m/s ({elapsed:.1f}s)")
        
        # 阶段3: 停止 (5-7秒)
        elif elapsed < 7.0:
            if self.phase != 'stop':
                self.phase = 'stop'
                self.get_logger().info("阶段3: 停止")
            
            # 发送解锁保持
            io_msg = IoCmd()
            io_msg.io_cmd_unlock = True
            io_msg.io_cmd_lamp_ctrl = True
            self.io_pub.publish(io_msg)
            
            # 发送停止命令
            ctrl_msg = CtrlCmd()
            ctrl_msg.ctrl_cmd_gear = 6
            ctrl_msg.ctrl_cmd_x_linear = 0.0
            ctrl_msg.ctrl_cmd_y_linear = 0.0
            ctrl_msg.ctrl_cmd_z_angular = 0.0
            self.ctrl_pub.publish(ctrl_msg)
        
        # 结束
        else:
            self.get_logger().info("测试完成")
            self.destroy_node()
            rclpy.shutdown()
        
        self.counter += 1

def main():
    rclpy.init()
    node = AGVTestController()
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        if rclpy.ok():
            node.destroy_node()
            rclpy.shutdown()

if __name__ == '__main__':
    main()
