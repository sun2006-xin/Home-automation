# 智慧家庭终端一键部署与全链路调试中心 (Terminal Debugger)

本工具专为分布式智慧家庭系统打造，用于**快速将闲置旧手机改造为智慧家庭固定中控面板**，以及**对各类 MCU 硬件节点（ESP32-C3 / STM32 等）进行一键固件烧录、日志监控与总线协议验证**。

---

## 1. 核心功能速览

| 模块 | 功能 | 说明 |
| :--- | :--- | :--- |
| 📱 **手机终端部署** | 一键安装与 Kiosk 锁定 | 自动检测连接手机，推送并安装最新 release APK，授予悬浮窗与开机自启权限，屏蔽状态栏/导航栏下拉，配置屏幕常亮，把旧手机无缝化身为工业级中控面板。 |
| 📸 **终端屏幕质检** | 实时屏幕截屏回传 | 一键截取手机终端当前横屏显示画面并拉取到电脑，方便远端检查 UI 状态、壁纸与交互反馈。 |
| 📋 **终端日志监视** | 实时 Logcat 过滤 | 专一流式过滤终端核心业务日志、触觉按键点击与音量键物理兜底事件。 |
| ⚡ **MCU 固件烧录** | 一键三合一烧录 | 自动扫描 COM 口，免配复杂的参数，直接调用 esptool 极速将 bootloader、partition-table 与 nodeESP 固件烧录至 ESP32-C3。 |
| 🖥️ **串口任务监视** | FreeRTOS 日志打印 | 打开 115200 波特率串口，实时解析节点 Wi-Fi 连网、MQTT 自发现、BLE 广播与电机运动事件。 |
| 🔍 **全系统健康巡检** | 固件与连接状态体检 | 一键检查 APK、MCU 固件二进制包、手机 ADB 连接与串口设备是否存在。 |

---

## 2. 快速使用方式

### 方式 A：双击运行 (Windows CMD)
直接双击运行本目录下的 `run_debugger.bat`，即可进入全彩交互式命令行主菜单。

### 方式 B：PowerShell 运行
```powershell
cd SmartHome/tools/terminal_debugger
.\run_debugger.ps1
```

### 方式 C：命令行非交互模式 (CI / 快捷调试)
```bash
# 全系统体检
python terminal_debugger.py --check

# 一键把插在 USB 上的手机改造成终端
python terminal_debugger.py --phone-install

# 截取手机终端当前画面
python terminal_debugger.py --phone-screenshot

# 监视手机终端日志
python terminal_debugger.py --phone-logs

# 烧录 ESP32-C3 节点固件 (自动检测 COM 口)
python terminal_debugger.py --flash-mcu

# 打开 COM3 串口监视器
python terminal_debugger.py --monitor-mcu COM3
```

---

## 3. 手机终端 Kiosk 工业专机策略详解

旧手机转换为专用控制面板时，本工具会自动执行以下系统级优化：
1. **防休眠策略 (`stay_on_while_plugged_in = 3`)**：插上充电器/电源线后永不黑屏灭屏；
2. **沉浸式保护 (`policy_control immersive.full`)**：彻底隐藏 Android 顶部状态栏和底部虚拟按键，防止误触退出；
3. **白名单保活 (`dumpsys deviceidle whitelist`)**：防止各厂商电源管理策略在后台冻结终端进程；
4. **物理兜底拦截 (`KeyEvent`)**：长按或双击手机音量物理按键，无需唤醒屏幕即可在断网/死机兜底场景下触发全开/全关。
