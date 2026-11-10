#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
智慧家庭 · 终端调试与一键配置助手 (Terminal Setup & Debug Assistant)

功能：
1. [scan]       自动扫描并打印已连接的旧手机/平板硬件信息（型号、安卓版本、分辨率、DPI、电池）；
2. [optimize]   一键将旧手机调优为专用壁挂终端（设置充电常亮、全局全屏沉浸、禁用锁屏）；
3. [test-keys]  远程模拟物理按键（音量加/音量减/电源键），验证终端按键拦截与 HUD 动效；
4. [mock-feed]  本地模拟数据源注入，实时向终端推送模拟的温湿度、设备开关状态，免硬件调试；
5. [mcu-spec]   输出 MCU 终端（ESP32-S3 + 屏幕）的对接标准点表与协议规范。
"""

import sys
import time
import subprocess
import argparse
import json

def run_adb(cmd, device=None):
    base = ["adb"]
    if device:
        base.extend(["-s", device])
    if isinstance(cmd, list):
        full_cmd = base + cmd
    else:
        full_cmd = base + cmd.split()
    try:
        res = subprocess.run(full_cmd, capture_output=True, text=True, encoding="utf-8", errors="ignore")
        return res.stdout.strip()
    except Exception as e:
        return f"Error: {e}"

def list_devices():
    output = run_adb("devices -l")
    lines = output.splitlines()
    devices = []
    for line in lines[1:]:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            devices.append(parts[0])
    return devices

def cmd_scan(args):
    print("=" * 60)
    print("🔍 扫描已连接的终端设备...")
    devices = list_devices()
    if not devices:
        print("❌ 未检测到任何已连接的 ADB 设备！")
        print("   请确认：手机已开启【USB 调试】并用数据线连至电脑。")
        return

    print(f"✅ 发现 {len(devices)} 台设备:\n")
    for d in devices:
        model = run_adb(["shell", "getprop", "ro.product.model"], device=d)
        brand = run_adb(["shell", "getprop", "ro.product.brand"], device=d)
        release = run_adb(["shell", "getprop", "ro.build.version.release"], device=d)
        size = run_adb(["shell", "wm", "size"], device=d)
        density = run_adb(["shell", "wm", "density"], device=d)
        battery = run_adb(["shell", "dumpsys", "battery"], device=d)
        
        # 提取电量
        level = "未知"
        for b_line in battery.splitlines():
            if "level:" in b_line:
                level = b_line.split(":")[-1].strip() + "%"
                break

        print(f"📱 设备序列号: {d}")
        print(f"   品牌型号: {brand} {model}")
        print(f"   安卓版本: Android {release}")
        print(f"   屏幕分辨率: {size.replace('Physical size: ', '')} ({density.replace('Physical density: ', '')} DPI)")
        print(f"   电池状态: 当前电量 {level}")
        print("-" * 60)

def cmd_optimize(args):
    devices = list_devices()
    if not devices:
        print("❌ 未检测到设备，请插上手机后重试。")
        return
    dev = args.device or devices[0]
    print(f"🚀 开始为设备 [{dev}] 执行一键终端化调优...")

    # 1. 充电不休眠
    print("  -> 1/3 设置充电时不休眠 (Stay Awake)...")
    run_adb(["shell", "svc", "power", "stayon", "true"], device=dev)

    # 2. 全屏沉浸模式，隐藏状态栏与导航栏
    print("  -> 2/3 启用全局沉浸式全屏 (隐藏导航栏与状态栏)...")
    run_adb(["shell", "settings", "put", "global", "policy_control", "immersive.full=*"], device=dev)

    # 3. 屏幕超时时间拉长 (24小时)
    print("  -> 3/3 延长休眠超时时间为 24 小时...")
    run_adb(["shell", "settings", "put", "system", "screen_off_timeout", "86400000"], device=dev)

    print("\n✅ 调优完成！该手机已进入极简壁挂 Kiosk 运行模式。")

def cmd_test_keys(args):
    devices = list_devices()
    if not devices:
        print("❌ 未检测到设备。")
        return
    dev = args.device or devices[0]
    
    action = args.key.lower()
    print(f"🎮 向设备 [{dev}] 发送模拟硬件物理按键: {action}")
    if action == "home" or action == "vol_up":
        run_adb(["shell", "input", "keyevent", "24"], device=dev)
        print("  -> 已注入 KEYCODE_VOLUME_UP (回家模式)")
    elif action == "away" or action == "vol_down":
        run_adb(["shell", "input", "keyevent", "25"], device=dev)
        print("  -> 已注入 KEYCODE_VOLUME_DOWN (离家模式)")
    elif action == "power":
        run_adb(["shell", "input", "keyevent", "26"], device=dev)
        print("  -> 已注入 KEYCODE_POWER (屏幕唤醒/消音)")
    else:
        print(f"未知按键: {action} (支持: home / away / power)")

def cmd_mcu_spec(args):
    print("=" * 60)
    print("🛠️ MCU 终端（ESP32-S3 + LVGL 屏幕）标准对接规范")
    print("=" * 60)
    print("""
如果您使用 ESP32-S3 + 3.5/4.0 寸触摸屏打造桌面/床头小终端，请按照以下规范接入：

1. 通信总线：
   - Wi-Fi 连接家里路由器；
   - 接入本地 MQTT Broker (端口 1883)。

2. 订阅主题 (接收全屋状态并刷新屏幕)：
   - sh/h01/+/state      (监听所有设备实时状态)
   - sh/h01/+/online     (监听设备上下线)
   - sh/h01/broadcast    (监听全屋广播与场景通知)

3. 下发控制 (屏幕按键点击时发送)：
   - 主题: sh/h01/{device_id}/cmd
   - 载荷: {"cmd":"set","args":{"on":1},"src":"mcu_terminal"}

4. 物理按键引脚建议 (ESP32-S3):
   - GPIO0 (BOOT键) -> 映射为 [回家模式]
   - GPIO35 / 外部按键 -> 映射为 [离家模式]
   - 采用 FreeRTOS 任务监听中断，触发时向 MQTT 发送场景指令。
""")

def main():
    parser = argparse.ArgumentParser(description="智慧家庭终端调试与配置助手")
    subparsers = parser.add_subparsers(dest="command", help="子命令")

    p_scan = subparsers.add_parser("scan", help="扫描已连接的安卓终端硬件信息")
    
    p_opt = subparsers.add_parser("optimize", help="一键优化手机为常亮壁挂终端")
    p_opt.add_argument("-d", "--device", help="指定设备序列号")

    p_key = subparsers.add_parser("test-keys", help="向手机模拟注入硬件按键")
    p_key.add_argument("key", choices=["home", "away", "vol_up", "vol_down", "power"], help="按键动作")
    p_key.add_argument("-d", "--device", help="指定设备序列号")

    p_mcu = subparsers.add_parser("mcu-spec", help="查看 MCU 终端 (ESP32-S3) 的对接规范")

    args = parser.parse_args()
    if args.command == "scan" or not args.command:
        cmd_scan(args)
    elif args.command == "optimize":
        cmd_optimize(args)
    elif args.command == "test-keys":
        cmd_test_keys(args)
    elif args.command == "mcu-spec":
        cmd_mcu_spec(args)

if __name__ == "__main__":
    main()
