#!/usr/bin/env python3
"""
AGV 完整测试脚本 - 同时发送解锁和控制命令

使用方法:
  python3 test_agv_full.py
"""
import rclpy
from rclpy.node import Node
from yhs_can_interfaces.msg import IoCmd, CtrlCmd
import time
import threading

class AGVFullTest(Node):
    def __init__(self):
        super().__init__('agv_full_test')
        
        # 创建发布者
        self.io_pub = self.create_publisher(IoCmd, '/io_cmd', 1)
        self.ctrl_pub = self.create_publisher(CtrlCmd, '/ctrl_cmd', 1)
        
        self.running = True
        self.counter = 0
        
        self.get_logger().info("AGV 完整测试已启动")
    
    def send_unlock(self):
        """发送解锁命令 (0x03 = unlock=1, lamp=1)"""
        msg = IoCmd()
        msg.io_cmd_unlock = True
        msg.io_cmd_lamp_ctrl = True
        self.io_pub.publish(msg)
    
    def send_control(self, gear, x_speed, y_speed=0.0, z_speed=0.0):
        """发送控制命令"""
        msg = CtrlCmd()
        msg.ctrl_cmd_gear = gear
        msg.ctrl_cmd_x_linear = x_speed
        msg.ctrl_cmd_y_linear = y_speed
        msg.ctrl_cmd_z_angular = z_speed
        self.ctrl_pub.publish(msg)
    
    def unlock_sequence(self):
        """发送4步解锁序列"""
        self.get_logger().info("步骤1: 发送解锁序列...")
        
        # Step 1: D0=0x02 (unlock=1, lamp=0)
        msg = IoCmd()
        msg.io_cmd_unlock = True
        msg.io_cmd_lamp_ctrl = False
        self.io_pub.publish(msg)
        time.sleep(0.02)
        
        # Step 2: D0=0x02
        self.io_pub.publish(msg)
        time.sleep(0.02)
        
        # Step 3: D0=0x00 (下降沿触发)
        msg.io_cmd_unlock = False
        self.io_pub.publish(msg)
        time.sleep(0.02)
        
        # Step 4: D0=0x00
        self.io_pub.publish(msg)
        time.sleep(0.02)
        
        self.get_logger().info("解锁序列完成")
    
    def run_test(self):
        """运行完整测试"""
        # 步骤1: 解锁序列
        self.unlock_sequence()
        
        # 步骤2: 持续解锁 + 控制 (3秒)
        self.get_logger().info("步骤2: 前进 0.1m/s，持续3秒...")
        start_time = time.time()
        
        while time.time() - start_time < 3.0 and self.running:
            # 每10ms发送一次解锁和控制命令
            self.send_unlock()
            self.send_control(6, 0.1, 0.0, 0.0)  # gear=6, x=0.1m/s
            time.sleep(0.01)
            
            if self.counter % 100 == 0:
                self.get_logger().info(f"运行中... {time.time() - start_time:.1f}s")
            self.counter += 1
        
        # 步骤3: 停止
        self.get_logger().info("步骤3: 停止...")
        for _ in range(50):  # 500ms
            self.send_unlock()
            self.send_control(6, 0.0, 0.0, 0.0)  # 停止
            time.sleep(0.01)
        
        self.get_logger().info("测试完成！")

def main():
    rclpy.init()
    node = AGVFullTest()
    
    try:
        # 在后台运行ROS2 spin
        thread = threading.Thread(target=rclpy.spin, args=(node,), daemon=True)
        thread.start()
        
        # 运行测试
        node.run_test()
        
    except KeyboardInterrupt:
        pass
    finally:
        node.running = False
        node.destroy_node()
        rclpy.shutdown()

if __name__ == '__main__':
    main()
