# ESP32-C3 SuperMini 智能窗帘节点固件 (C01)

基于 **ESP-IDF v5.4** 与 **FreeRTOS** 原生架构开发的智能窗帘节点固件。支持四相八拍非阻塞步进电机驱动、物理按键兜底控制、状态指示灯反馈，以及近场 BLE GATT 直控协议栈。

---

## 1. 硬件引脚配置 (ESP32-C3 SuperMini)

| 节点外设 | ESP32-C3 GPIO | 连接说明 | 备注 |
| :--- | :--- | :--- | :--- |
| **步进驱动 IN1** | **GPIO 4** | 连接 ULN2003 驱动板 IN1 (A相) | 5V/12V 28BYJ-48 步进电机 |
| **步进驱动 IN2** | **GPIO 5** | 连接 ULN2003 驱动板 IN2 (B相) | 四相八拍时序激励 |
| **步进驱动 IN3** | **GPIO 6** | 连接 ULN2003 驱动板 IN3 (C相) | 4096 步/周期 |
| **步进驱动 IN4** | **GPIO 7** | 连接 ULN2003 驱动板 IN4 (D相) | 到达目标自动关断线圈消热 |
| **状态指示灯** | **GPIO 8** | 板载蓝色 LED (低电平点亮) | 呼吸/闪烁状态机指示 |
| **物理兜底按键** | **GPIO 9** | 板载 Boot 键或外接按键引脚至 GND | 内部弱上拉，防抖动处理 |

---

## 2. 核心架构与功能特性

### 2.1 驱动与逻辑分层
```text
nodeESP/
├── main/
│   ├── app_main.c         # 固件主入口，初始化 NVS、Link、BLE 与监控循环
│   ├── node_config.h      # 节点参数宏定义 (引脚、时序、UUID、设备名)
│   ├── driver/
│   │   ├── drv_stepper.c  # ULN2003 四相八拍非阻塞微步驱动，到位自动断电降温
│   │   ├── drv_key.c      # 物理按键 20ms 防抖，短按翻转、长按急停
│   │   └── drv_led.c      # LED 状态指示（常灭、常亮、慢闪、快闪）
│   ├── link/
│   │   ├── link.h         # 硬件能力抽象层 (apply / query / poll)
│   │   └── link_gpio.c    # 窗帘位置到步进电机目标步数的精确映射
│   └── net/
│       ├── net_ble.h      # BLE 直控协议栈接口
│       └── net_ble.c      # NimBLE GATT 服务与广播实现
├── build_output/          # 预编译好的生产级二进制文件
│   ├── bootloader.bin     # 一级引导加载程序 (0x0)
│   ├── partition-table.bin# 分区表 (0x8000)
│   └── nodeESP.bin        # 应用程序固件 (0x10000)
├── flash.ps1              # Windows PowerShell 一键烧录脚本
└── flash.bat              # Windows CMD 一键烧录批处理
```

### 2.2 物理兜底与安全机制
- **短按 (<1秒)**：智能翻转窗帘状态。如果当前为开 (位置 > 0)，则全关 (0%)；如果当前为关 (位置 = 0)，则全开 (100%)。即使 Wi-Fi/网络或上位机断开，物理按键依然 100% 具备本地可用性。
- **长按 (>3秒)**：紧急制动与零点校准。立即停止步进电机运动，并将当前位置复位为全关基准点。
- **线圈自动断电 (Anti-Heat Cutoff)**：步进电机到位后，驱动模块自动将 GPIO 4~7 全部拉低，切断 ULN2003 达林顿管静态偏置电流，杜绝电机与驱动板静态发热，大幅降低功耗。

---

## 3. BLE GATT 直控协议规范

智能终端或调试助手可通过近场蓝牙 BLE 直接控制本节点，无需任何网关。

- **广播设备名**：`SH_CURTAIN_C01`
- **主服务 UUID**：`0xFFE0`
- **特征值列表**：
  - **控制特征 (CMD UUID: `0xFFE1`)**：
    - **属性**：`WRITE` / `WRITE_WITHOUT_RESPONSE`
    - **负载数据**：
      - 方式 1（ASCII 字符串）：`"0"` ~ `"100"`（例如发送 `"50"` 表示开度 50%）
      - 方式 2（单字节数值）：`0x00` ~ `0x64`（例如发送 `0x32` 表示 50%）
  - **状态特征 (STATE UUID: `0xFFE2`)**：
    - **属性**：`READ` / `NOTIFY`
    - **负载数据**：单字节无符号整数（`0` ~ `100`），表示当前窗帘实时开度百分比。

---

## 4. 一键烧录与部署

### 4.1 免编译直接烧录 (推荐)
仓库中的 `build_output/` 目录已附带预编译完成的最新二进制固件。将 ESP32-C3 SuperMini 插入电脑 USB 口：

**使用 PowerShell 脚本**：
```powershell
cd SmartHome/firmware/nodeESP
.\flash.ps1 -Port COM3
```

**或者双击运行 `flash.bat`**，按提示输入 COM 口即可。

### 4.2 从源码重新编译
如果二次开发修改了代码，需在 ESP-IDF v5.4 环境下执行编译：
```powershell
. D:\esp\esp-idf\export.ps1
cd SmartHome/firmware/nodeESP
python D:\esp\esp-idf\tools\idf.py -B D:\esp_build\nodeESP build
```
编译完成后运行以下命令同步产物到 `build_output`：
```powershell
cp D:\esp_build\nodeESP\bootloader\bootloader.bin build_output\
cp D:\esp_build\nodeESP\partition_table\partition-table.bin build_output\
cp D:\esp_build\nodeESP\nodeESP.bin build_output\
```

---

## 5. 调试与验证方法

1. **上电验证**：
   - 插入 Type-C 供电，板载 LED 将慢闪，表明 BLE 广播已正常启动。
2. **手机调试 APP 测试 (nRF Connect / LightBlue)**：
   - 扫描周围蓝牙设备，连接 `SH_CURTAIN_C01`。
   - 展开服务 `0xFFE0`，在 `0xFFE1` 特征中写入十六进制 `32`（十进制 50）。
   - 观察步进电机平稳转动半周，到达后 LED 常亮提示到位。
3. **按键物理兜底测试**：
   - 短按 GPIO 9 按键，电机自动执行全开/全关翻转；
   - 运动中长按 3 秒，电机立刻急停并复位。
