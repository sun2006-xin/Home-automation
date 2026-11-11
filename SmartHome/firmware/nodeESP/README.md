# SmartHome 分布式节点固件 (ESP32-S3 / ESP32-C3 一码双芯)

基于 **ESP-IDF v5.4** 与 **FreeRTOS** 原生架构开发的分布式智能节点固件（当前角色：Phase M1 `C01` 客厅主窗帘节点）。同一份源码可通过 `idf.py set-target esp32s3` 或 `esp32c3` 编译并运行在两款芯片上，自动适配引脚、栈空间与 NimBLE 协议栈。

---

## 1. 一码双芯引脚与安全边界对比

| 节点外设 | ESP32-S3 (`esp32s3`) | ESP32-C3 SuperMini (`esp32c3`) | 接线与硬件说明 |
| :--- | :--- | :--- | :--- |
| **步进驱动 IN1 (A相)** | **GPIO 4** | **GPIO 4** | ULN2003 驱动板 IN1，两芯片通用安全引脚 |
| **步进驱动 IN2 (B相)** | **GPIO 5** | **GPIO 5** | ULN2003 驱动板 IN2，两芯片通用安全引脚 |
| **步进驱动 IN3 (C相)** | **GPIO 6** | **GPIO 6** | ULN2003 驱动板 IN3，4096 步/行程周期 |
| **步进驱动 IN4 (D相)** | **GPIO 7** | **GPIO 7** | ULN2003 驱动板 IN4，到位后自动拉低断电消热 |
| **物理兜底按键** | **GPIO 0** (板载 BOOT) | **GPIO 9** (板载 BOOT) | 内部上拉，低电平触发；短按翻转开合，长按 >3s 急停零点校准 |
| **状态指示灯** | **GPIO 2** (高电平亮外接 LED) | **GPIO 8** (低电平亮板载蓝灯) | S3 常见板载 RGB 为 GPIO 48 (WS2812)，故缺省预留 GPIO 2 |

> [!WARNING]
> **ESP32-S3 二次扩展引脚禁区**：
> - **GPIO 26 ~ 37**：内部连接 SPI Flash / Octal PSRAM（尤其 N8R8 / N16R8 模组），**严禁作为普通 GPIO 使用**。
> - **GPIO 19 ~ 20**：ESP32-S3 原生 USB OTG D-/D+ 引脚，开启 USB 串口日志时勿占用。
> - **GPIO 3 / 45 / 46**：Strapping 启动配置引脚，避免挂接强下拉或高负载外设。

---

## 2. 实测编译体积与内存占用对比 (ESP-IDF v5.4)

两款芯片均已通过 `idf.py build` + `idf.py size` 全链路编译与内存审计（包含 NimBLE + WiFi + MQTT 完整组件）：

| 指标 | ESP32-S3 (`esp32s3` 双核 Xtensa LX7) | ESP32-C3 (`esp32c3` 单核 RISC-V) | 工程对比结论 |
| :--- | :--- | :--- | :--- |
| **App 固件体积 (`nodeESP.bin`)** | `1,094,544 B` (3MB 分区剩余 **65%**) | `1,188,224 B` (3MB 分区剩余 **62%**) | S3 指令密度略高，少占 ~91 KB Flash |
| **Bootloader (`bootloader.bin`)** | `21,008 B` (`0x5210`) | `20,816 B` (`0x5150`) | 均保留 36% 余量，烧录起始地址同为 `0x0` |
| **静态内存 (`DIRAM / DRAM`)** | `136,815 / 341,760 B` (**剩余 204,945 B**) | `141,672 / 321,296 B` (**剩余 179,624 B**) | S3 静态占用 40.03%，多出 **~25 KB** 运行期裕量 |
| **专用高速 `IRAM`** | `16,383 / 16,384 B` (溢出已安全映射 DIRAM) | 统一归入 DRAM/IRAM 共享池 | `led_task=2048B`, `key_scan_task=3072B` 适配 Xtensa |
| **USB/UART 串口日志** | 主 UART0 + 次级 `USB_SERIAL_JTAG` 并发 | 默认串口/USB-JTAG | S3 插入任意 Type-C 均可直接观察日志 |

> 针对 ESP32-S3 Xtensa LX7 更深的函数窗口保存帧，已在 `drv_led.c` (`2048B`)、`drv_key.c` (`3072B`) 及 `sdkconfig.defaults` (`MAIN_TASK=4096B`) 放大任务栈，防止按键/日志触发栈溢出。

---

## 3. 核心架构与功能特性

```text
nodeESP/
├── main/
│   ├── app_main.c            # 固件主入口，初始化 NVS、Link、BLE、WiFi 与 MQTT 监控循环
│   ├── node_config.h         # 一码双芯条件编译引脚配置 & 设备角色定义
│   ├── driver/
│   │   ├── drv_stepper.c     # ULN2003 四相八拍非阻塞微步驱动，到位自动断电降温
│   │   ├── drv_key.c         # 物理按键 20ms 防抖，短按翻转、长按急停 (3072B 栈安全加固)
│   │   └── drv_led.c         # LED 状态指示（常灭、常亮、慢闪、快闪）
│   ├── link/
│   │   ├── link.h / link_gpio.c # 硬件能力抽象与开度-步数映射
│   └── net/
│       ├── net_ble.c / .h    # NimBLE GATT 服务 (0xFFE0 / 0xFFE1 / 0xFFE2)
│       ├── net_wifi.c / .h   # WiFi STA 指数退避自动重连
│       └── net_mqtt.c / .h   # sh/{home}/{dev}/{online,state,cmd,_discovery} 总线接入
├── sdkconfig.defaults        # 目标无关通用默认配置 (NimBLE / 4MB / 3MB App / 主栈 4KB)
├── sdkconfig.defaults.esp32s3
├── sdkconfig.defaults.esp32c3
├── build_output/
│   ├── s3/                   # ESP32-S3 预编译三合一固件 (0x0 / 0x8000 / 0x10000)
│   └── c3/                   # ESP32-C3 预编译三合一固件 (0x0 / 0x8000 / 0x10000)
├── flash.ps1 / flash.bat     # 支持 -Chip esp32s3 / esp32c3 的一键烧录脚本
```

---

## 4. 一键烧录与源码编译

### 4.1 免编译直接烧录 (推荐)

插入开发板后在 PowerShell 中执行（默认目标 `esp32s3`）：

```powershell
cd SmartHome/firmware/nodeESP
.\flash.ps1 -Chip esp32s3 -Port COM3
```

如需烧录旧版 ESP32-C3 SuperMini：
```powershell
.\flash.ps1 -Chip esp32c3 -Port COM3
```

### 4.2 从源码切换芯片编译 (ESP-IDF v5.4)

因工程目录含中文路径，推荐将构建目录与独立 `SDKCONFIG` 置于纯英文路径：

```powershell
. D:\esp\esp-idf\export.ps1
$py  = "D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe"
$idf = "D:\esp\esp-idf\tools\idf.py"

# 编译 ESP32-S3
& $py $idf -B D:\esp_build\nodeESP_s3 -D SDKCONFIG=D:\esp_build\nodeESP_s3\sdkconfig set-target esp32s3
& $py $idf -B D:\esp_build\nodeESP_s3 -D SDKCONFIG=D:\esp_build\nodeESP_s3\sdkconfig build

# 编译 ESP32-C3
& $py $idf -B D:\esp_build\nodeESP_c3 -D SDKCONFIG=D:\esp_build\nodeESP_c3\sdkconfig set-target esp32c3
& $py $idf -B D:\esp_build\nodeESP_c3 -D SDKCONFIG=D:\esp_build\nodeESP_c3\sdkconfig build
```
