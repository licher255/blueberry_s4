#!/usr/bin/env python3
"""
WHJ CAN-FD 测试脚本
用于测试RealMan WHJ升降机构的CAN-FD通信
"""

import can
import time
import struct
import argparse

# WHJ CAN IDs (需要根据实际协议调整)
WHJ_POSITION_CMD_ID = 0x01
WHJ_VELOCITY_CMD_ID = 0x02
WHJ_POSITION_FB_ID = 0x101
WHJ_STATUS_FB_ID = 0x102


def test_canfd_connection(interface='can1'):
    """测试CAN-FD连接"""
    print(f"[*] 测试 CAN-FD 接口: {interface}")
    
    try:
        # 尝试使用CAN-FD模式创建总线
        bus = can.interface.Bus(
            channel=interface,
            bustype='socketcan',
            fd=True,  # 启用CAN-FD
            bitrate=1000000,
            data_bitrate=5000000
        )
        print(f"[+] CAN-FD 总线创建成功: {interface}")
        return bus
    except Exception as e:
        print(f"[-] CAN-FD 连接失败: {e}")
        print("[*] 尝试使用标准CAN模式...")
        try:
            bus = can.interface.Bus(
                channel=interface,
                bustype='socketcan'
            )
            print(f"[+] 标准CAN总线创建成功: {interface}")
            return bus
        except Exception as e2:
            print(f"[-] 标准CAN连接也失败: {e2}")
            return None


def send_position_command(bus, position_mm, speed_mm_s=50):
    """发送位置控制命令"""
    # 数据打包 (示例格式，需要根据实际协议调整)
    data = struct.pack('<hh', int(position_mm), int(speed_mm_s))
    
    msg = can.Message(
        arbitration_id=WHJ_POSITION_CMD_ID,
        data=data,
        is_extended_id=False
    )
    
    try:
        bus.send(msg)
        print(f"[+] 发送位置命令: pos={position_mm}mm, speed={speed_mm_s}mm/s")
        return True
    except Exception as e:
        print(f"[-] 发送失败: {e}")
        return False


def listen_feedback(bus, timeout=5):
    """监听反馈消息"""
    print(f"[*] 监听反馈消息 ({timeout}s)...")
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        msg = bus.recv(timeout=0.1)
        if msg:
            print(f"[RX] ID=0x{msg.arbitration_id:03X}, Data={msg.data.hex()}")
            
            if msg.arbitration_id == WHJ_POSITION_FB_ID:
                # 解析位置反馈
                if len(msg.data) >= 4:
                    pos, target = struct.unpack('<hh', msg.data[:4])
                    print(f"    当前位置: {pos}mm, 目标位置: {target}mm")
                    
            elif msg.arbitration_id == WHJ_STATUS_FB_ID:
                # 解析状态反馈
                if len(msg.data) >= 2:
                    error_code = struct.unpack('<H', msg.data[:2])[0]
                    print(f"    错误码: 0x{error_code:04X}")


def main():
    parser = argparse.ArgumentParser(description='WHJ CAN-FD 测试工具')
    parser.add_argument('-i', '--interface', default='can1', help='CAN接口名称')
    parser.add_argument('-p', '--position', type=float, help='目标位置(mm)')
    parser.add_argument('-s', '--speed', type=float, default=50, help='速度(mm/s)')
    parser.add_argument('-l', '--listen', action='store_true', help='只监听反馈')
    
    args = parser.parse_args()
    
    print("=" * 50)
    print("RealMan WHJ CAN-FD 测试工具")
    print("=" * 50)
    
    # 连接CAN
    bus = test_canfd_connection(args.interface)
    if not bus:
        print("[-] 无法连接到CAN设备")
        return 1
    
    try:
        if args.listen:
            # 只监听模式
            listen_feedback(bus, timeout=60)
        elif args.position is not None:
            # 发送位置命令
            send_position_command(bus, args.position, args.speed)
            # 等待反馈
            listen_feedback(bus, timeout=5)
        else:
            # 默认：只监听
            listen_feedback(bus, timeout=10)
            
    except KeyboardInterrupt:
        print("\n[*] 用户中断")
    finally:
        bus.shutdown()
        print("[*] CAN总线已关闭")
    
    return 0


if __name__ == '__main__':
    exit(main())
