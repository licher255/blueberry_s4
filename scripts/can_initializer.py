#!/usr/bin/env python3
"""Blueberry S4 - CAN 设备初始化器 (动态驱动映射版)"""

import os
import sys
import time
import yaml
import subprocess
from pathlib import Path

PROJECT_DIR = Path(__file__).parent.parent.resolve()
CONFIG_FILE = PROJECT_DIR / "config" / "can_devices.yaml"

class C:
    R = '\033[0;31m'; G = '\033[0;32m'; Y = '\033[1;33m'
    B = '\033[0;34m'; C = '\033[0;36m'; NC = '\033[0m'

def info(m): print(f"{C.B}[CAN]{C.NC} {m}")
def ok(m): print(f"{C.G}[CAN]{C.NC} {m}")
def warn(m): print(f"{C.Y}[CAN]{C.NC} {m}")
def err(m): print(f"{C.R}[CAN]{C.NC} {m}")

def header():
    print(f"\n{C.C}╔════════════════════════════════════════════════════════╗{C.NC}")
    print(f"{C.C}║{C.NC}     🔌 CAN 设备初始化 (动态映射)                       {C.C}║{C.NC}")
    print(f"{C.C}╚════════════════════════════════════════════════════════╝{C.NC}\n")

def run(cmd, check=True):
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)
        return r.returncode == 0, r.stdout, r.stderr
    except:
        return False, "", ""

def is_root(): return os.geteuid() == 0

def load_config():
    if not CONFIG_FILE.exists():
        err(f"配置不存在: {CONFIG_FILE}")
        return None
    try:
        with open(CONFIG_FILE) as f:
            return yaml.safe_load(f)
    except Exception as e:
        err(f"加载配置失败: {e}")
        return None

def get_can_mapping():
    """检测 CAN 接口映射: 返回 {driver: interface} 如 {'pcan': 'can2', 'usbcanfd': 'can3'}"""
    mapping = {}
    success, out, _ = run("ls /sys/class/net/ 2>/dev/null | grep -E '^can' | sort -V", check=False)
    if not success:
        return mapping
    
    for iface in out.strip().split('\n'):
        iface = iface.strip()
        if not iface:
            continue
        _, details, _ = run(f"ip -details link show {iface} 2>/dev/null", check=False)
        if "usbcanfd:" in details:
            mapping["usbcanfd"] = iface
        elif "pcan:" in details:
            mapping["pcan"] = iface
        elif "mttcan:" in details:
            mapping["mttcan"] = iface
    
    return mapping

def load_driver(name, path="", params=""):
    """加载驱动，支持参数"""
    success, _, _ = run(f"lsmod | grep -E '^{name}'", check=False)
    if success:
        return True
    # 尝试带参数加载
    if path:
        ko = PROJECT_DIR / path
        if ko.exists():
            cmd = f"insmod {ko}"
            if params:
                cmd += f" {params}"
            return run(cmd, check=False)[0]
    # 尝试 modprobe
    if run(f"modprobe {name}", check=False)[0]:
        return True
    return False

def unload_driver(name):
    run(f"rmmod {name} 2>/dev/null", check=False)

def setup_iface(iface, cfg):
    mode = cfg.get("mode", "can")
    bitrate = cfg.get("bitrate", 500000)
    
    run(f"ip link set {iface} down 2>/dev/null", check=False)
    
    if mode == "canfd":
        dbitrate = cfg.get("dbitrate", 5000000)
        success, _, _ = run(f"ip link set {iface} type can bitrate {bitrate} dbitrate {dbitrate} fd on")
        if not success:
            warn(f"CAN-FD 失败，使用普通 CAN")
            run(f"ip link set {iface} type can bitrate {bitrate}")
    else:
        run(f"ip link set {iface} type can bitrate {bitrate}")
    
    run(f"ip link set {iface} up")
    return True

def init_can():
    header()
    
    if not is_root():
        err("需要 root: sudo ./s4 init")
        return 1
    
    cfg = load_config()
    if not cfg:
        return 1
    
    # 1. 清理
    info("清理驱动...")
    for i in range(2, 10):
        run(f"ip link set can{i} down 2>/dev/null", check=False)
    unload_driver("pcan")
    unload_driver("usbcanfd")
    time.sleep(2)
    
    # 2. 加载基础模块
    for mod in ["can", "can_raw", "can_dev"]:
        run(f"modprobe {mod} 2>/dev/null", check=False)
    
    # 3. 按顺序加载驱动
    info("加载驱动...")
    for drv in cfg.get("driver_load_order", []):
        name = drv["name"]
        module = drv["module"]
        path = drv.get("path", "")
        wait = drv.get("wait_time", 2)
        
        # ZLG 驱动：确保启用终端电阻 (cfg_term_res=1)
        params = ""
        if name == "usbcanfd":
            params = "cfg_term_res=1"
            info(f"  {name} (终端电阻启用)")
        
        if load_driver(module, path, params):
            ok(f"  {name} 已加载")
            time.sleep(wait)
        else:
            err(f"  {name} 加载失败")
    
    # 4. 检测映射
    info("检测接口映射...")
    mapping = get_can_mapping()
    
    if not mapping:
        err("未找到任何 CAN 接口")
        return 1
    
    for driver, iface in mapping.items():
        info(f"  {driver} -> {iface}")
    
    # 5. 根据映射配置接口
    info("配置接口...")
    devices_cfg = cfg.get("can_devices", {})
    
    for driver_type, device_cfg in devices_cfg.items():
        iface = mapping.get(driver_type)
        if not iface:
            warn(f"未找到 {driver_type} 的接口")
            continue
        
        if not device_cfg.get("auto_start", True):
            continue
        
        desc = device_cfg.get("description", driver_type)
        info(f"配置 {desc} ({driver_type})...")
        
        if setup_iface(iface, device_cfg):
            ok(f"  {iface} 已启用: {device_cfg.get('mode', 'can')} @ {device_cfg.get('bitrate')}bps")
            
            # 保存映射供后续使用
            run(f"echo '{iface}' > /tmp/can_{driver_type}.iface", check=False)
    
    # 6. 最终状态
    info("当前状态:")
    _, out, _ = run("ip -br link show type can")
    for line in out.strip().split("\n"):
        if line.strip():
            print(f"  {line}")
    
    # 7. 显示映射摘要
    print("")
    ok("CAN 初始化完成")
    print("")
    info("设备映射:")
    for driver, iface in mapping.items():
        dev_cfg = devices_cfg.get(driver, {})
        desc = dev_cfg.get("description", driver)
        hw_cfg = dev_cfg.get("hardware", {})
        print(f"  {desc}: {iface} ({driver})")
        # 显示终端电阻状态
        if driver == "usbcanfd" and hw_cfg.get("terminal_resistor", False):
            ok(f"    终端电阻: 已启用 (120Ω)")
    
    return 0

if __name__ == "__main__":
    sys.exit(init_can())
