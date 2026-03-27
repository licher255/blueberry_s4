#!/bin/bash
# AGV CAN 信号硬编码测试脚本
# 严格遵循YUHESEN官方协议
#
# 使用方法:
#   ./can_debug_test.sh          # 自动检测 pcan 接口
#   ./can_debug_test.sh can3     # 指定接口

# 动态检测 pcan 接口
get_pcan_interface() {
    # 方法1: 检查缓存文件
    if [ -f /tmp/can_pcan.iface ]; then
        cat /tmp/can_pcan.iface
        return 0
    fi
    
    # 方法2: 实时检测
    for iface in $(ls /sys/class/net/ 2>/dev/null | grep -E '^can' | sort -V); do
        if ip -details link show "$iface" 2>/dev/null | grep -q "pcan:"; then
            echo "$iface"
            return 0
        fi
    done
    
    return 1
}

# 获取CAN接口
if [ $# -ge 1 ]; then
    CAN_IF="$1"
else
    CAN_IF=$(get_pcan_interface)
    if [ -z "$CAN_IF" ]; then
        echo "错误: 未找到 pcan 接口，请指定接口名称 (如: ./can_debug_test.sh can3)"
        exit 1
    fi
fi

echo "======================================"
echo "   AGV CAN 硬编码信号测试"
echo "======================================"
echo ""
echo "使用接口: $CAN_IF"
echo "此脚本将直接发送CAN帧，绕过ROS"
echo ""

# 检查CAN接口
if ! ip link show $CAN_IF 2>/dev/null | grep -q "UP"; then
    echo "错误: $CAN_IF 未启动"
    echo "请先运行: sudo ./scripts/s4 init"
    exit 1
fi

echo "=== 步骤1: 发送解锁序列 ==="
echo "按照官方协议: 0x02 -> 0x12 -> 0x20 -> 0x30 (带CRC和Counter)"

# 解锁序列 - 严格按照手册
# ID 0x18C4D7D0
cansend $CAN_IF 18C4D7D0#0200000000000002
echo "  解锁帧1: D0=0x02 (unlock=1, lamp=0, counter=0, crc=0x02)"
sleep 0.02

cansend $CAN_IF 18C4D7D0#0200000000000012
echo "  解锁帧2: D0=0x02 (unlock=1, lamp=0, counter=1, crc=0x12)"
sleep 0.02

cansend $CAN_IF 18C4D7D0#0000000000000020
echo "  解锁帧3: D0=0x00 (unlock=0, lamp=0, counter=2, crc=0x20) - 下降沿触发!"
sleep 0.02

cansend $CAN_IF 18C4D7D0#0000000000000030
echo "  解锁帧4: D0=0x00 (unlock=0, lamp=0, counter=3, crc=0x30)"
sleep 0.02

echo ""
echo "=== 步骤2: 持续发送解锁保持信号 ==="
echo "使用 0x03 (unlock=1, lamp=1) 保持解锁状态"

for i in {0..9}; do
    # D0=0x03 (unlock=1, lamp=1)
    # D6=counter (0-15)
    # D7=crc = D0^D6 = 0x03^counter
    counter=$(printf "%01X" $i)
    crc=$(printf "%02X" $((0x03 ^ i)))
    cansend $CAN_IF 18C4D7D0#03000000000000${counter}${crc}
    echo "  保持解锁: counter=$counter, crc=0x$crc"
    sleep 0.01
done

echo ""
echo "=== 步骤3: 发送前进命令 (0.3 m/s) ==="
echo "档位6 (4T4D), X速度=0.3m/s (300 = 0x012C)"

# 速度编码:
# X = 300 (0x012C) = 0.3 m/s
# Byte0: gear(0-3) | X(3-0) = 0x6 | 0xC = 0x6C? 
# 等等，让我重新计算...

# 根据手册:
# D0[3:0] = gear = 6 = 0x6
# D0[7:4] = X[3:0] = 0xC (300的低4位是0xC)
# D0 = 0xC6

# D1 = X[11:4] = 0x12 (300的高8位)

# D2[3:0] = X[15:12] = 0x0 (符号扩展)
# D2[7:4] = Z[3:0] = 0x0
# D2 = 0x00

# D3 = Z[11:4] = 0x00
# D4 = Z[15:12] | Y[3:0] = 0x00
# D5 = Y[11:4] = 0x00
# D6[3:0] = counter
# D6[7:4] = Y[15:12] = 0x00
# D7 = CRC

for i in {0..19}; do
    counter=$(printf "%01X" $i)
    # D0=0xC6 (gear=6, X低4位=0xC)
    # D1=0x12 (X高8位)
    # D2=0x00 (X符号扩展=0, Z低4位=0)
    # D3=0x00 (Z高8位)
    # D4=0x00 (Z符号扩展, Y低4位)
    # D5=0x00 (Y高8位)
    # D6=0x0${counter} (Y符号扩展, counter)
    # D7=CRC
    crc=$(printf "%02X" $((0xC6 ^ 0x12 ^ 0x00 ^ 0x00 ^ 0x00 ^ 0x00 ^ (i))))
    cansend $CAN_IF 18C4D1D0#C6120000000000${counter}${crc}
    echo "  前进命令: counter=$counter"
    sleep 0.05
done

echo ""
echo "=== 步骤4: 发送停止命令 ==="
cansend $CAN_IF 18C4D1D0#0600000000000006
echo "  停止: gear=6, X=0, Z=0"

echo ""
echo "=== 测试完成 ==="
echo "观察AGV是否有以下动作:"
echo "  1. 解锁时可能有蜂鸣器或指示灯变化"
echo "  2. 前进时轮子应该转动"
echo ""
