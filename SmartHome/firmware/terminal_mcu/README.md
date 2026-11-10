# MCU 独立智慧家庭中控终端 (Terminal MCU)

针对不想用旧手机、希望使用 **ESP32 / ESP32-S3 / STM32** 配合独立彩色显示屏（做成 86 盒墙面面板、桌面中控或旋钮屏）的用户打造的嵌入式中控固件。

基于 **ESP-IDF v5.4** 与 **LVGL 8/9** 打造，具备**多屏幕硬件抽象（Display HAL）**与**响应式弹性排版引擎（Responsive Flexbox Engine）**。

---

## 1. 为什么 MCU 能在没有系统的情况下自适应任意屏幕？

手机终端有 Android 系统的 DPI 和 WindowManager 进行自动缩放，而 MCU 裸机/FreeRTOS 默认只有固定像素。为了让一份代码在任意屏幕上都能完美排版，我们设计了**三层解耦适配引擎**：

```text
terminal_mcu/
├── bsp/
│   ├── bsp_display_config.h  # 【唯一硬件配置】：修改分辨率、驱动芯片(ST7789/ILI9341/GC9A01)、引脚
│   ├── bsp_display.h         # 硬件驱动抽象层接口
│   └── bsp_display.c         # 基于 esp_lcd + DMA 双缓冲的极速像素管道
├── ui/
│   ├── ui_theme_tokens.h     # 【设计令牌】：按屏幕尺寸计算 UI 缩放比、动态字号与温暖原木配色
│   ├── ui_adaptive_deck.h    # 响应式中控卡片界面接口
│   └── ui_adaptive_deck.c    # 【弹性排版】：基于 LV_FLEX_FLOW_ROW_WRAP 与百分比宽度的自适应卡片流
└── main/
    ├── CMakeLists.txt        # 组件依赖注册
    └── main.c                # 固件主入口与 LVGL 调度循环
```

---

## 2. 四大自适应核心机制

### 2.1 彻底消灭绝对坐标，全用相对百分比（Flexbox & Percentage）
- 严禁在代码中写死像素坐标 `lv_obj_set_pos(x, y)`；
- 采用现代前端与 Flutter 的 **Flexbox 弹性流式布局 (`LV_FLEX_FLOW_ROW_WRAP`)**；
- 容器宽度全部设定为百分比：
  - 在宽屏（横向 ≥ 320px）上：每张电器卡片占 `48%` 宽度，一行并排排 2 张卡片，自动均分间隙；
  - 在窄屏或圆屏（横向 ≤ 260px，如 240x240）上：卡片自动计算占 `96%` 宽度，自动退化为单列卡片垂直滚动流，**绝无任何元素溢出或重叠**！

### 2.2 响应式设计令牌 (Responsive Design Tokens)
在 `ui_theme_tokens.h` 中，系统会根据硬件设定的 `LV_HOR_RES` 动态导出不同等级的物理令牌：
```c
/* 视口规格动态判定 */
#define UI_IS_SMALL_SCREEN   (LV_HOR_RES <= 260)              /* 240x240 旋钮/桌面小方屏 */
#define UI_IS_MEDIUM_SCREEN  (LV_HOR_RES > 260 && LV_HOR_RES <= 400) /* 320x240 2.8寸标准屏 */
#define UI_IS_LARGE_SCREEN   (LV_HOR_RES > 400)               /* 480x320 3.5寸 86盒大面板 */

/* 卡片宽度自适应 */
#define TOKEN_CARD_WIDTH_PCT (UI_IS_SMALL_SCREEN ? lv_pct(96) : lv_pct(48))

/* 字号自适应 */
#define TOKEN_FONT_TITLE     (UI_IS_LARGE_SCREEN ? &lv_font_montserrat_20 : \
                             (UI_IS_MEDIUM_SCREEN ? &lv_font_montserrat_14 : &lv_font_montserrat_12))
```

### 2.3 温暖原木风视觉语言统一 (Warm Japandi Style)
MCU 终端的调色板（`UI_COLOR_BG`, `UI_COLOR_CARD_BG`, `UI_COLOR_BTN_ACTIVE`）与手机终端保持 100% 视觉一致性：
- 柔和深咖色半透卡片背景 (`0x281E16`)
- 温暖琥珀色高亮按键 (`0xD86A38`)
- 羊脂暖白主文字 (`0xFFF7F0`)，告别冰冷生硬的黑白极客风。

---

## 3. 用户如何更换不同屏幕？（1分钟教程）

用户在淘宝或开发板上购买了不同型号的屏幕时，**无需改动任何一行 UI 代码**，只需打开 [`bsp/bsp_display_config.h`](file:///d:/智慧家庭/SmartHome/firmware/terminal_mcu/bsp/bsp_display_config.h) 修改前几行宏：

### 案例 1：换用 2.8 寸 320×240 横屏（ST7789 驱动，推荐缺省配置）
```c
#define BSP_DISPLAY_HOR_RES         320
#define BSP_DISPLAY_VER_RES         240
#define BSP_DISPLAY_ROTATION_DEG    90
#define BSP_DISPLAY_DRIVER_TYPE     BSP_DISPLAY_DRIVER_ST7789
```

### 案例 2：换用 1.28 寸 240×240 圆形旋钮屏（GC9A01 驱动）
```c
#define BSP_DISPLAY_HOR_RES         240
#define BSP_DISPLAY_VER_RES         240
#define BSP_DISPLAY_ROTATION_DEG    0
#define BSP_DISPLAY_DRIVER_TYPE     BSP_DISPLAY_DRIVER_GC9A01
```
*此时系统自动激活 `UI_IS_SMALL_SCREEN`，卡片自动变为单列，上下滑动顺畅舒适！*

### 案例 3：换用 3.5 寸 480×320 86 盒大屏（ILI9341 或 ST7796 驱动）
```c
#define BSP_DISPLAY_HOR_RES         480
#define BSP_DISPLAY_VER_RES         320
#define BSP_DISPLAY_ROTATION_DEG    90
#define BSP_DISPLAY_DRIVER_TYPE     BSP_DISPLAY_DRIVER_ILI9341
```
*此时系统自动激活 `UI_IS_LARGE_SCREEN`，字号与内边距自动按比例放大，两列卡片充盈大屏！*

---

## 4. 推荐硬件接线表 (ESP32-S3 / ESP32 默认 SPI 引脚)

| 屏幕引脚 | ESP32-S3 GPIO | 说明 |
| :--- | :--- | :--- |
| **SCLK / SCL** | **GPIO 18** | SPI 时钟线 (40MHz) |
| **MOSI / SDA** | **GPIO 19** | SPI 主出从入数据线 |
| **CS** | **GPIO 5** | 片选信号 (低电平有效) |
| **DC / RS** | **GPIO 4** | 命令/数据选择引脚 |
| **RST / RES** | **GPIO 2** | 硬件复位引脚 |
| **BLK / LED** | **GPIO 15** | 背光控制引脚 (支持 PWM 调光) |
| **VCC** | **3.3V 或 5V** | 根据屏幕模块供电规范连接 |
| **GND** | **GND** | 电源共地 |
