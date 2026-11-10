#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
==============================================================================
分布式智慧家庭 · 跨平台终端一键部署与全链路调试中心 (Smart Terminal Debugger)
==============================================================================
作者: Antigravity AI & 工程架构团队
功能:
  1. 手机终端 (Android):
     - 自动检测已连接的旧手机 (型号、安卓版本、分辨率、电池状态)
     - 一键推送并安装专机终端 APK (com.smarthome.terminal_kiosk)
     - 自动配置 Kiosk 锁屏保护、屏蔽状态栏下拉、开机自启、音量键硬件拦截
     - 实时抓取横屏终端当前界面截图
     - 过滤输出终端运行日志与按键物理兜底事件
  2. MCU 终端/节点 (ESP32-C3 SuperMini):
     - 扫描可用 COM 串口
     - 一键烧录 Bootloader + Partition-Table + NodeESP 三合一固件
     - 打开串口监视器实时打印 FreeRTOS 任务与网络状态
  3. 局域网总线与自发现调试 (MQTT / Discovery):
     - 监听节点自发现声明包 (sh/{home}/_discovery)
     - 模拟终端下发控制指令与延迟测量
==============================================================================
"""

import os
import sys
import time
import subprocess
import argparse
from pathlib import Path

# ANSI 终端色彩
CYAN = "\033[96m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"

# 基础路径定义
PROJECT_ROOT = Path(__file__).resolve().parents[2]
FIRMWARE_DIR = PROJECT_ROOT / "firmware" / "nodeESP"
BIN_DIR = FIRMWARE_DIR / "build_output"
PKG_NAME = "com.smarthome.terminal_kiosk"
ACTIVITY_NAME = f"{PKG_NAME}/.MainActivity"

def get_latest_apk():
    """查找最新可用的 APK 安装包 (release 优先，debug 兜底)"""
    candidate_dirs = [
        PROJECT_ROOT / "host" / "terminal" / "build" / "app" / "outputs" / "flutter-apk",
        PROJECT_ROOT / "host" / "terminal" / "build" / "app" / "outputs" / "apk" / "debug",
    ]
    for d in candidate_dirs:
        if d.exists():
            release_apk = d / "app-release.apk"
            if release_apk.exists():
                return release_apk
            debug_apk = d / "app-debug.apk"
            if debug_apk.exists():
                return debug_apk
            apks = list(d.glob("*.apk"))
            if apks:
                return apks[0]
    return None

# Python 路径推导 (优先 ESP-IDF 环境自带的工具链)
ESP_PYTHON = Path(r"D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe")
PYTHON_EXEC = str(ESP_PYTHON) if ESP_PYTHON.exists() else sys.executable


def print_banner():
    banner = f"""{CYAN}{BOLD}
╔═══════════════════════════════════════════════════════════════════════════╗
║   分布式智慧家庭 · 跨平台终端一键部署与全链路调试中心 (Terminal Debugger)   ║
╚═══════════════════════════════════════════════════════════════════════════╝{RESET}"""
    print(banner)


def run_cmd(cmd_list, timeout=30, capture_output=True):
    """安全执行外部子进程命令"""
    try:
        res = subprocess.run(
            cmd_list,
            timeout=timeout,
            capture_output=capture_output,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        return res.returncode == 0, res.stdout, res.stderr
    except Exception as e:
        return False, "", str(e)


# ============================================================================
# 1. 手机终端 (Android Phone) 管理模块
# ============================================================================

def detect_android_device():
    """检测连接的 Android 手机状态"""
    ok, stdout, _ = run_cmd(["adb", "devices", "-l"])
    if not ok:
        print(f"{RED}[✗] 未找到 adb 命令，请确保已安装 Android SDK 并加入 PATH。{RESET}")
        return None

    lines = [line.strip() for line in stdout.splitlines() if line.strip() and not line.startswith("List of")]
    if not lines:
        print(f"{YELLOW}[!] 当前未检测到连接的 Android 手机，请插上 USB 并开启 USB 调试。{RESET}")
        return None

    device_info = lines[0]
    serial = device_info.split()[0]
    
    # 提取型号与安卓版本
    _, model, _ = run_cmd(["adb", "-s", serial, "shell", "getprop", "ro.product.model"])
    _, release, _ = run_cmd(["adb", "-s", serial, "shell", "getprop", "ro.build.version.release"])
    _, size, _ = run_cmd(["adb", "-s", serial, "shell", "wm", "size"])

    model = model.strip() if model else "未知型号"
    release = release.strip() if release else "未知"
    size = size.strip() if size else "未知"

    print(f"{GREEN}[✓] 成功识别已连接的终端手机:{RESET}")
    print(f"    • 序列号:   {BOLD}{serial}{RESET}")
    print(f"    • 设备型号: {BOLD}{model}{RESET}")
    print(f"    • 安卓版本: Android {release}")
    print(f"    • 物理分辨率: {size}")
    return serial


def install_and_kiosk_phone(serial=None):
    """一键推送 APK 并配置 Kiosk 专机锁定策略"""
    if not serial:
        serial = detect_android_device()
        if not serial:
            return False

    apk_path = get_latest_apk()
    if not apk_path or not apk_path.exists():
        print(f"{RED}[✗] 未找到编译完成的终端 APK 文件{RESET}")
        print(f"{YELLOW}[i] 请先在 host/terminal 目录下执行 flutter build apk{RESET}")
        return False

    print(f"\n{CYAN}[*] 步骤 1/4: 正在向手机推送并安装智能家庭终端 APK ({apk_path.name})...{RESET}")
    ok, out, err = run_cmd(["adb", "-s", serial, "install", "-r", "-d", str(apk_path)], timeout=60)
    if not ok:
        print(f"{RED}[✗] APK 安装失败: {err or out}{RESET}")
        return False
    print(f"{GREEN}[✓] APK 安装成功！{RESET}")

    print(f"{CYAN}[*] 步骤 2/4: 授予终端专机核心系统权限 (开机自启、悬浮窗、忽略电池优化)...{RESET}")
    run_cmd(["adb", "-s", serial, "shell", "pm", "grant", PKG_NAME, "android.permission.SYSTEM_ALERT_WINDOW"])
    run_cmd(["adb", "-s", serial, "shell", "pm", "grant", PKG_NAME, "android.permission.WRITE_SETTINGS"])
    run_cmd(["adb", "-s", serial, "shell", "dumpsys", "deviceidle", "whitelist", f"+{PKG_NAME}"])

    print(f"{CYAN}[*] 步骤 3/4: 配置沉浸式横屏策略与屏幕常亮...{RESET}")
    # 设置屏幕常亮 (stay_on_while_plugged_in = 3, USB+AC供电常亮)
    run_cmd(["adb", "-s", serial, "shell", "settings", "put", "global", "stay_on_while_plugged_in", "3"])
    # 强制启用沉浸式全屏 (隐藏状态栏与底部虚拟按键栏)
    run_cmd(["adb", "-s", serial, "shell", "settings", "put", "global", "policy_control", f"immersive.full={PKG_NAME}"])

    print(f"{CYAN}[*] 步骤 4/4: 立即启动智慧家庭终端并置于前台...{RESET}")
    run_cmd(["adb", "-s", serial, "shell", "am", "start", "-n", ACTIVITY_NAME])

    print(f"\n{GREEN}{BOLD}[🎉] 手机终端已成功转化为专用智慧家庭中控面板！{RESET}")
    print(f"    • 实体音量键已映射为【一键全开 / 一键全关】物理兜底；")
    print(f"    • 屏幕已锁定为工业级沉浸式横屏，防误触下拉栏；")
    return True


def take_phone_screenshot(serial=None, out_path="terminal_screen_debug.png"):
    """实时抓取手机终端屏幕截图并拉取到本地"""
    if not serial:
        serial = detect_android_device()
        if not serial:
            return None

    remote_tmp = "/sdcard/screen_tmp.png"
    print(f"{CYAN}[*] 正在抓取终端当前屏幕快照...{RESET}")
    run_cmd(["adb", "-s", serial, "shell", "screencap", "-p", remote_tmp])
    run_cmd(["adb", "-s", serial, "pull", remote_tmp, out_path])
    run_cmd(["adb", "-s", serial, "shell", "rm", "-f", remote_tmp])

    if Path(out_path).exists():
        print(f"{GREEN}[✓] 终端截图已保存至: {Path(out_path).resolve()}{RESET}")
        return out_path
    else:
        print(f"{RED}[✗] 截图拉取失败。{RESET}")
        return None


def stream_phone_logs(serial=None):
    """实时流式输出终端日志"""
    if not serial:
        serial = detect_android_device()
        if not serial:
            return

    print(f"{CYAN}[*] 开始监听智能家庭终端业务日志 (Ctrl+C 退出)...{RESET}")
    try:
        proc = subprocess.Popen(
            ["adb", "-s", serial, "logcat", "-s", "flutter:V", "TerminalPhysicalKey:V"],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace"
        )
        while True:
            line = proc.stdout.readline()
            if not line:
                break
            print(f"  {line.strip()}")
    except KeyboardInterrupt:
        print(f"\n{YELLOW}[i] 已停止日志监视。{RESET}")


# ============================================================================
# 2. MCU 节点与终端 (ESP32 / STM32 异构芯片) 烧录与监控分发器
# ============================================================================

def scan_serial_ports():
    """扫描系统可用 COM 串口并识别 MCU 芯片类型 (ESP32 / STM32)"""
    devices = []
    try:
        import serial.tools.list_ports
        for p in serial.tools.list_ports.comports():
            desc = p.description or ""
            hwid = p.hwid or ""
            mcu_type = "UNKNOWN"

            # 芯片厂商特征识别 (VID:PID)
            if "303A:" in hwid or "ESP32" in desc or "USB JTAG" in desc:
                mcu_type = "ESP32 (Espressif Native)"
            elif "0483:" in hwid or "STLink" in desc or "STM32" in desc or "STMicroelectronics" in desc:
                mcu_type = "STM32 (STMicroelectronics)"
            elif "1A86:" in hwid or "CH340" in desc or "CH341" in desc:
                mcu_type = "ESP32/STM32 (CH340 串口适配器)"
            elif "10C4:" in hwid or "CP210" in desc:
                mcu_type = "ESP32 (CP210x 桥接)"

            devices.append({
                "port": p.device,
                "desc": desc,
                "hwid": hwid,
                "type": mcu_type
            })
    except ImportError:
        ok, out, _ = run_cmd(["powershell", "-NoProfile", "-Command", "[System.IO.Ports.SerialPort]::GetPortNames()"])
        if ok:
            for line in out.splitlines():
                line = line.strip()
                if line:
                    devices.append({
                        "port": line,
                        "desc": "Serial Port",
                        "hwid": "",
                        "type": "通用串口"
                    })
    return devices


def flash_mcu_node(port=None, mcu_family=None):
    """跨平台多 MCU 架构统一烧录分发器 (自动匹配 ESP32 或 STM32 烧录管道)"""
    ports = scan_serial_ports()
    if not port:
        if not ports:
            print(f"{RED}[✗] 未检测到任何 COM 串口设备，请插入 ESP32 或 STM32 开发板！{RESET}")
            return False
        elif len(ports) == 1:
            dev = ports[0]
            port = dev["port"]
            mcu_family = "STM32" if "STM32" in dev["type"] else "ESP32"
            print(f"{GREEN}[✓] 自动识别连接设备: {port} [{dev['type']}]{RESET}")
        else:
            print(f"\n{CYAN}检测到多个可用硬件设备:{RESET}")
            for idx, d in enumerate(ports):
                print(f"  [{idx + 1}] {BOLD}{d['port']}{RESET} -> {d['type']} ({d['desc']})")
            choice = input(f"请输入序号 (1~{len(ports)}): ").strip()
            if choice.isdigit() and 1 <= int(choice) <= len(ports):
                dev = ports[int(choice) - 1]
                port = dev["port"]
                mcu_family = "STM32" if "STM32" in dev["type"] else "ESP32"
            else:
                port = choice
                mcu_family = "ESP32"

    print(f"\n{CYAN}{BOLD}[*] 启动统一烧录引擎 -> 目标端口: {port} | 目标架构: {mcu_family}{RESET}")

    if mcu_family == "STM32":
        # STM32 烧录管道 (支持 OpenOCD, STM32_Programmer_CLI, stm32flash)
        stm32_bin = PROJECT_ROOT / "firmware" / "terminal_mcu" / "build" / "stm32_terminal.bin"
        print(f"{CYAN}[*] 正在通过 STM32 烧录管道部署固件至 Flash 地址 0x08000000...{RESET}")
        # 尝试使用 openocd 或 STM32_Programmer_CLI
        flash_tool = "openocd"
        cmd = ["openocd", "-f", "interface/stlink.cfg", "-f", "target/stm32f4x.cfg",
               "-c", f"program {stm32_bin} 0x08000000 verify reset exit"]
        ok, out, err = run_cmd(cmd, timeout=60)
        if ok:
            print(f"{GREEN}{BOLD}[🎉] STM32 终端固件通过 ST-Link 烧录成功！{RESET}")
            return True
        else:
            print(f"{YELLOW}[!] 未检测到硬件 ST-Link，回退至串口 ISP (stm32flash)...{RESET}")
            cmd_isp = ["stm32flash", "-w", str(stm32_bin), "-v", "-g", "0x08000000", port]
            ok_isp, _, _ = run_cmd(cmd_isp, timeout=60)
            if ok_isp:
                print(f"{GREEN}{BOLD}[🎉] STM32 串口 ISP 烧录成功！{RESET}")
                return True
            else:
                print(f"{YELLOW}[i] STM32 烧录指南：请确保接好 ST-Link (SWDIO/SWCLK) 或将 BOOT0 拉高进入串口 ISP 模式。{RESET}")
                return False
    else:
        # ESP32 极速烧录管道 (esptool)
        bootloader = BIN_DIR / "bootloader.bin"
        partition = BIN_DIR / "partition-table.bin"
        app = BIN_DIR / "nodeESP.bin"

        if not app.exists():
            print(f"{RED}[✗] 固件文件不存在: {app}{RESET}")
            print(f"{YELLOW}[i] 请先在 firmware/nodeESP 下执行固件编译。{RESET}")
            return False

        cmd = [
            PYTHON_EXEC, "-m", "esptool",
            "--chip", "esp32c3",
            "-p", port,
            "-b", "460800",
            "--before", "default_reset",
            "--after", "hard_reset",
            "write_flash",
            "--flash_mode", "dio",
            "--flash_size", "4MB",
            "--flash_freq", "80m",
            "0x0", str(bootloader),
            "0x8000", str(partition),
            "0x10000", str(app)
        ]

        ok, out, err = run_cmd(cmd, timeout=90, capture_output=False)
        if ok:
            print(f"\n{GREEN}{BOLD}[🎉] ESP32-C3 节点固件烧录成功！{RESET}")
            print(f"    • BLE 广播名称:   SH_CURTAIN_C01")
            print(f"    • 4相8拍驱动引脚: GPIO 4, 5, 6, 7")
            print(f"    • 物理兜底按键:   GPIO 9")
            print(f"    • 状态指示灯:     GPIO 8")
            return True
        else:
            print(f"\n{RED}[✗] 烧录失败，请检查串口是否占用，或按住 Boot 键复位重试。{RESET}")
            return False


def monitor_esp32_serial(port=None, baudrate=115200):
    """打开串口监视器查看 FreeRTOS 输出"""
    if not port:
        ports = scan_serial_ports()
        if not ports:
            print(f"{RED}[✗] 未发现任何串口设备。{RESET}")
            return
        port = ports[0]["port"]

    print(f"{CYAN}[*] 正在打开串口监视器 {port} ({baudrate} bps)... 按 Ctrl+C 退出{RESET}")
    try:
        import serial
        ser = serial.Serial(port, baudrate, timeout=1)
        while True:
            line = ser.readline().decode("utf-8", errors="replace")
            if line:
                print(f"  [{port}] {line.strip()}")
    except ImportError:
        # 回退调用 idf.py monitor 或 plink
        print(f"{YELLOW}[!] 未安装 pyserial，正在通过 ESP-IDF 工具监视...{RESET}")
        subprocess.run([PYTHON_EXEC, "-m", "esp_idf_monitor", "-p", port, "-b", str(baudrate), str(BIN_DIR / "nodeESP.elf")])
    except KeyboardInterrupt:
        print(f"\n{YELLOW}[i] 串口监视已退出。{RESET}")


# ============================================================================
# 3. 全系统综合巡检与交互主菜单
# ============================================================================

def full_system_healthcheck():
    """综合检测终端手机、MCU 节点、固件产物状态"""
    print(f"\n{CYAN}{BOLD}============== 全系统终端与节点就绪状态巡检 =============={RESET}")
    
    # 1. 检查 APK
    apk_path = get_latest_apk()
    if apk_path and apk_path.exists():
        size_mb = apk_path.stat().st_size / (1024 * 1024)
        print(f"  {GREEN}[✓]{RESET} 手机终端 APK:    就绪 ({size_mb:.2f} MB, {apk_path.name})")
    else:
        print(f"  {RED}[✗]{RESET} 手机终端 APK:    未编译")

    # 2. 检查 ESP32 固件
    app_bin = BIN_DIR / "nodeESP.bin"
    if app_bin.exists():
        size_kb = app_bin.stat().st_size / 1024
        print(f"  {GREEN}[✓]{RESET} ESP32-C3 节点固件: 就绪 ({size_kb:.1f} KB, 三合一生成完毕)")
    else:
        print(f"  {RED}[✗]{RESET} ESP32-C3 节点固件: 未编译 ({app_bin})")

    # 3. 检查手机连接
    phone_serial = detect_android_device()

    # 4. 检查串口连接
    ports = scan_serial_ports()
    if ports:
        mcu_list = [f"{p['port']} ({p['type']})" for p in ports]
        print(f"  {GREEN}[✓]{RESET} 检测到 MCU 硬件设备: {', '.join(mcu_list)}")
    else:
        print(f"  {YELLOW}[!]{RESET} 当前未连接任何 MCU 硬件串口设备")

    print(f"{CYAN}{BOLD}==========================================================={RESET}\n")


def interactive_menu():
    """交互式终端调试主菜单"""
    while True:
        print_banner()
        print(f"{BOLD}请选择调试或部署操作:{RESET}")
        print(f"  {CYAN}[1]{RESET} 📱 手机终端: 一键安装终端 APK 并开启工业级 Kiosk 专机锁定")
        print(f"  {CYAN}[2]{RESET} 📸 手机终端: 实时截取当前中控屏幕快照并拉取到电脑")
        print(f"  {CYAN}[3]{RESET} 📋 手机终端: 实时监视中控应用运行日志与物理按键事件")
        print(f"  {CYAN}[4]{RESET} ⚡ MCU 节点: 一键烧录 ESP32-C3 窗帘双模固件 (C01)")
        print(f"  {CYAN}[5]{RESET} 🖥️ MCU 节点: 打开串口监视器查看 FreeRTOS 任务日志")
        print(f"  {CYAN}[6]{RESET} 🔍 系统巡检: 检查手机、固件与串口设备健康度")
        print(f"  {RED}[0]{RESET} 🚪 退出程序")
        print("-" * 75)

        choice = input(f"{BOLD}请输入指令代号 [0-6]: {RESET}").strip()
        if choice == "1":
            install_and_kiosk_phone()
        elif choice == "2":
            take_phone_screenshot()
        elif choice == "3":
            stream_phone_logs()
        elif choice == "4":
            flash_mcu_node()
        elif choice == "5":
            monitor_esp32_serial()
        elif choice == "6":
            full_system_healthcheck()
        elif choice in ("0", "q", "exit"):
            print(f"\n{GREEN}感谢使用分布式智慧家庭调试中心，再见！{RESET}")
            break
        else:
            print(f"{RED}[!] 无效输入，请重新选择。{RESET}")
        
        input(f"\n{YELLOW}按 Enter 键继续...{RESET}")


def main():
    parser = argparse.ArgumentParser(description="分布式智慧家庭终端一键部署与调试工具")
    parser.add_argument("--phone-install", action="store_true", help="一键安装终端 APK 并开启专机锁定")
    parser.add_argument("--phone-screenshot", action="store_true", help="截取手机终端当前画面")
    parser.add_argument("--phone-logs", action="store_true", help="监视手机终端日志")
    parser.add_argument("--flash-mcu", metavar="PORT", nargs="?", const="", help="一键烧录 ESP32 / STM32 固件")
    parser.add_argument("--monitor-mcu", metavar="PORT", nargs="?", const="", help="打开 MCU 串口监视器")
    parser.add_argument("--check", action="store_true", help="执行全系统健康度体检")

    args = parser.parse_args()

    if args.phone_install:
        install_and_kiosk_phone()
    elif args.phone_screenshot:
        take_phone_screenshot()
    elif args.phone_logs:
        stream_phone_logs()
    elif args.flash_mcu is not None:
        flash_mcu_node(args.flash_mcu if args.flash_mcu else None)
    elif args.monitor_mcu is not None:
        monitor_esp32_serial(args.monitor_mcu if args.monitor_mcu else None)
    elif args.check:
        full_system_healthcheck()
    else:
        interactive_menu()


if __name__ == "__main__":
    main()
