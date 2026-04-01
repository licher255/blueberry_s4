#!/usr/bin/env python3
import rclpy
from rclpy.node import Node
from yhs_can_interfaces.msg import IoCmd, CtrlCmd
import time

rclpy.init()
node = Node('test_node')
io_pub = node.create_publisher(IoCmd, '/io_cmd', 1)
cmd_pub = node.create_publisher(CtrlCmd, '/ctrl_cmd', 1)

print("发送解锁序列...")
for i in range(20):
    msg = IoCmd()
    msg.io_cmd_unlock = True
    msg.io_cmd_lamp_ctrl = True
    io_pub.publish(msg)
    time.sleep(0.05)

print("前进 0.2m/s，3秒...")
for i in range(100):
    msg = IoCmd()
    msg.io_cmd_unlock = True
    msg.io_cmd_lamp_ctrl = True
    io_pub.publish(msg)
    
    cmd = CtrlCmd()
    cmd.ctrl_cmd_gear = 6
    cmd.ctrl_cmd_x_linear = 0.2
    cmd.ctrl_cmd_y_linear = 0.0
    cmd.ctrl_cmd_z_angular = 0.0
    cmd_pub.publish(cmd)
    time.sleep(0.03)

print("停止")
for i in range(20):
    msg = IoCmd()
    msg.io_cmd_unlock = True
    msg.io_cmd_lamp_ctrl = True
    io_pub.publish(msg)
    
    cmd = CtrlCmd()
    cmd.ctrl_cmd_gear = 6
    cmd.ctrl_cmd_x_linear = 0.0
    cmd_ctrl_y_linear = 0.0
    cmd.ctrl_cmd_z_angular = 0.0
    cmd_pub.publish(cmd)
    time.sleep(0.05)

node.destroy_node()
rclpy.shutdown()
print("完成")
