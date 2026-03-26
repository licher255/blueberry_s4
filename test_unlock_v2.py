#!/usr/bin/env python3
"""
AGV解锁测试脚本 V2
完全匹配YUHESEN C++驱动的实现
"""
import socket
import struct
import time
import sys

# 创建CAN socket
sock = socket.socket(socket.PF_CAN, socket.SOCK_RAW, socket.CAN_RAW)
interface = b"can3"
sock.bind((interface,))

# 设置接收超时
sock.settimeout(2.0)

def build_frame(can_id, data):
    """构建CAN帧 - 使用扩展帧格式"""
    # 内核会自动添加CAN_EFF_FLAG，所以这里直接用原始ID
    can_id_packed = struct.pack('<I', can_id | socket.CAN_EFF_FLAG)
    dlc = len(data)
    data_padded = data + bytes(8 - len(data))
    frame = can_id_packed + bytes([dlc, 0, 0, 0]) + data_padded
    return frame

def send_io_cmd(d0, d6, d1=0, d2=0, d3=0, d4=0, d5=0):
    """发送IO命令 - 匹配C++实现"""
    can_id = 0x18C4D7D0
    # CRC: D0^D1^D2^D3^D4^D5^D6
    crc = d0 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6
    data = bytes([d0, d1, d2, d3, d4, d5, d6, crc])
    frame = build_frame(can_id, data)
    sock.send(frame)
    return crc, data

def send_ctrl_cmd(gear, x_speed, y_speed, z_speed, count):
    """发送控制命令 - 完全匹配C++实现"""
    can_id = 0x18C4D1D0
    
    # 转换速度值 (和C++代码一致)
    x_raw = int(x_speed * 1000)  # 0.001 m/s/bit
    y_raw = int(y_speed * 1000)  # 0.001 m/s/bit  
    z_raw = int(z_speed * 100)   # 0.01 deg/s/bit (注意C++里 SteeringCtrlCmd 用100)
    
    # 构建数据字节 (和C++代码完全一致)
    d0 = (gear & 0x0F) | ((x_raw & 0x0F) << 4)
    d1 = (x_raw >> 4) & 0xFF
    d2 = ((x_raw >> 12) & 0x0F) | ((z_raw & 0x0F) << 4)
    d3 = (z_raw >> 4) & 0xFF
    d4 = ((z_raw >> 12) & 0x0F) | ((y_raw & 0x0F) << 4)
    d5 = (y_raw >> 4) & 0xFF
    d6 = ((y_raw >> 12) & 0x0F) | (count << 4)
    
    crc = d0 ^ d1 ^ d2 ^ d3 ^ d4 ^ d5 ^ d6
    
    data = bytes([d0, d1, d2, d3, d4, d5, d6, crc])
    frame = build_frame(can_id, data)
    sock.send(frame)
    return data

def recv_frame():
    """接收一帧CAN数据"""
    try:
        frame = sock.recv(16)
        can_id = struct.unpack('<I', frame[0:4])[0]
        dlc = frame[4]
        data = frame[8:8+dlc]
        return can_id, data
    except socket.timeout:
        return None, None

def check_io_feedback(timeout=3):
    """检查IO反馈，返回unlock状态"""
    print("检查IO反馈...")
    start = time.time()
    while time.time() - start < timeout:
        can_id, data = recv_frame()
        if can_id is None:
            continue
        # 检查IO反馈ID (带扩展帧标志)
        if (can_id & 0x1FFFFFFF) == 0x18C4DAEF:
            if len(data) >= 1:
                d0 = data[0]
                unlock = (d0 >> 1) & 0x01
                lamp = d0 & 0x01
                print(f"  IO反馈: D0=0x{d0:02X}, unlock={unlock}, lamp={lamp}")
                return unlock == 1
    print("  未收到IO反馈")
    return False

def check_ctrl_feedback(timeout=3):
    """检查控制反馈，返回档位"""
    print("检查控制反馈...")
    start = time.time()
    while time.time() - start < timeout:
        can_id, data = recv_frame()
        if can_id is None:
            continue
        # 检查控制反馈ID
        if (can_id & 0x1FFFFFFF) == 0x18C4D1EF:
            if len(data) >= 1:
                gear = data[0] & 0x0F
                print(f"  控制反馈: gear={gear}")
                return gear
    print("  未收到控制反馈")
    return None

print("=" * 60)
print("AGV解锁和运动测试")
print("=" * 60)

# 步骤1: 发送4步解锁序列 (严格20ms间隔)
print("\n[步骤1] 发送4步解锁序列...")
count = 0

# Step 1: D0=0x02 (unlock=1), D6=0x00 (alive=0, 高4位)
crc, data = send_io_cmd(0x02, 0x00)
print(f"  Step1: D0=0x02, D6=0x00, CRC=0x{crc:02X}, Data={data.hex()}")
time.sleep(0.02)

# Step 2: D0=0x02 (unlock=1), D6=0x10 (alive=1)
crc, data = send_io_cmd(0x02, 0x10)
print(f"  Step2: D0=0x02, D6=0x10, CRC=0x{crc:02X}")
time.sleep(0.02)

# Step 3: D0=0x00 (unlock=0, 下降沿!), D6=0x20 (alive=2)
crc, data = send_io_cmd(0x00, 0x20)
print(f"  Step3: D0=0x00, D6=0x20, CRC=0x{crc:02X}")
time.sleep(0.02)

# Step 4: D0=0x00 (unlock=0), D6=0x30 (alive=3)
crc, data = send_io_cmd(0x00, 0x30)
print(f"  Step4: D0=0x00, D6=0x30, CRC=0x{crc:02X}")
time.sleep(0.02)

print("\n[步骤2] 检查解锁状态...")
unlocked = check_io_feedback()

if not unlocked:
    print("  AGV未解锁，尝试持续解锁...")
    
    # 持续发送解锁命令
    for i in range(50):
        count = i % 16
        d6 = count << 4
        crc, data = send_io_cmd(0x03, d6)  # 0x03 = unlock=1, lamp=1
        if i < 5:
            print(f"  持续解锁 {i}: D0=0x03, D6=0x{d6:02X}, CRC=0x{crc:02X}")
        
        # 每10帧检查一次反馈
        if i % 10 == 0:
            if check_io_feedback(timeout=0.5):
                print("  AGV已解锁！")
                unlocked = True
                break
        
        time.sleep(0.05)

if unlocked:
    print("\n[步骤3] 发送控制命令...")
    # 发送控制命令: gear=6, x=0.3m/s
    for i in range(20):
        count = i % 16
        data = send_ctrl_cmd(6, 0.3, 0, 0, count)
        if i < 3:
            print(f"  控制命令 {i}: {data.hex()}")
        time.sleep(0.1)
    
    print("\n[步骤4] 检查AGV是否运动...")
    gear = check_ctrl_feedback(timeout=3)
    if gear == 6:
        print("✓ AGV档位已切换到6，正在运动！")
    else:
        print(f"✗ AGV档位仍是{gear}，未运动")
else:
    print("\n✗ 解锁失败")

sock.close()
print("\n测试完成")
