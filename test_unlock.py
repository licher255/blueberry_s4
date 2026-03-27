#!/usr/bin/env python3
"""
AGV解锁和运动测试脚本 (简化版)

使用方法:
  python3 test_unlock.py            # 自动检测 pcan 接口
  python3 test_unlock.py can3       # 指定接口
"""
import socket
import struct
import time
import sys
import os
import glob
import subprocess

def get_pcan_interface():
    """动态检测 pcan 接口"""
    # 方法1: 检查缓存文件
    cache_file = "/tmp/can_pcan.iface"
    if os.path.exists(cache_file):
        with open(cache_file, 'r') as f:
            iface = f.read().strip()
            if iface:
                return iface
    
    # 方法2: 实时检测
    for iface in sorted(glob.glob('/sys/class/net/can*')):
        iface_name = os.path.basename(iface)
        try:
            result = subprocess.run(['ip', '-details', 'link', 'show', iface_name], 
                                  capture_output=True, text=True)
            if 'pcan:' in result.stdout:
                return iface_name
        except:
            pass
    
    return None

# 获取CAN接口
if len(sys.argv) > 1:
    interface_name = sys.argv[1]
else:
    interface_name = get_pcan_interface()
    if interface_name is None:
        print("错误: 未找到 pcan 接口，请指定接口名称 (如: python3 test_unlock.py can3)")
        sys.exit(1)

print(f"使用接口: {interface_name}")

sock = socket.socket(socket.PF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
sock.bind((interface_name.encode(),))

def build_frame(can_id, data):
    can_id_packed = struct.pack('<I', can_id | socket.CAN_EFF_FLAG)
    dlc = len(data)
    data_padded = data + bytes(8 - len(data))
    frame = can_id_packed + bytes([dlc, 0, 0, 0]) + data_padded
    return frame

def send_io_cmd(d0, d6):
    can_id = 0x18C4D7D0
    crc = d0 ^ 0 ^ 0 ^ 0 ^ 0 ^ 0 ^ d6
    data = bytes([d0, 0, 0, 0, 0, 0, d6, crc])
    frame = build_frame(can_id, data)
    sock.send(frame)
    return crc

def send_ctrl_cmd(gear, x_speed, z_speed, alive):
    """发送控制命令"""
    can_id = 0x18C4D1D0
    
    # X速度: 0.001 m/s/bit
    x_raw = int(x_speed * 1000)
    # Z角速度: 0.01 deg/s/bit
    z_raw = int(z_speed * 100 * 57.2958)  # rad/s to deg/s
    
    # 构建数据
    d0 = (gear & 0x0F) | ((x_raw & 0x0F) << 4)
    d1 = (x_raw >> 4) & 0xFF
    d2 = ((x_raw >> 12) & 0x0F) | ((z_raw & 0x0F) << 4)
    d3 = (z_raw >> 4) & 0xFF
    d4 = (z_raw >> 12) & 0xFF
    d5 = 0x00
    d6 = (alive & 0x0F) << 4  # alive在高4位
    
    # CRC: D0^D1^D2^D3^D4^D5^D6
    crc = d0 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6
    
    data = bytes([d0, d1, d2, d3, d4, d5, d6, crc])
    frame = build_frame(can_id, data)
    sock.send(frame)

# 发送解锁序列 (20ms间隔，严格按协议)
print("发送4步解锁序列...")
send_io_cmd(0x02, 0x00)  # Step1: unlock=1, alive=0
time.sleep(0.02)
send_io_cmd(0x02, 0x10)  # Step2: unlock=1, alive=1
time.sleep(0.02)
send_io_cmd(0x00, 0x20)  # Step3: unlock=0 (下降沿!), alive=2
time.sleep(0.02)
send_io_cmd(0x00, 0x30)  # Step4: unlock=0, alive=3
print("解锁序列完成!")

# 解锁序列后立即开始持续解锁
time.sleep(0.02)
print("开始持续解锁...")

# 持续发送解锁+控制命令
print("持续发送命令10秒...")
for i in range(100):
    alive = (i % 16) << 4
    
    # 发送解锁命令 (0x03 = unlock=1, lamp=1)
    send_io_cmd(0x03, alive)
    
    # 每10帧发送一次控制命令
    if i % 10 == 0:
        send_ctrl_cmd(6, 0.3, 0, i % 16)  # gear=6, x=0.3m/s
    
    time.sleep(0.1)

sock.close()
print("完成!")
