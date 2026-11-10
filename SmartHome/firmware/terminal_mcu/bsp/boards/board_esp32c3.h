/**
 * @file board_esp32c3.h
 * @brief ESP32-C3 SuperMini 硬件中控面板引脚画像
 *
 * 硬件安全纪律：
 * - GPIO 8:  Strapping 引脚（低电平进入下载模式，启动时必须谨慎）
 * - GPIO 9:  Strapping / BOOT 键
 * - GPIO 18/19: 原生 USB JTAG 串口
 * - 本配置文件已严格绕开敏感硬件引脚，杜绝引脚打架与变砖隐患！
 */

#pragma once

#define BOARD_CHIP_NAME         "ESP32-C3 RISC-V"
#define BOARD_BUS_TYPE_SPI      1

/* 推荐专属高速 SPI 显示屏引脚 */
#define PIN_LCD_SCLK            4       /* SPI SCLK (GPIO 4) */
#define PIN_LCD_MOSI            6       /* SPI MOSI (GPIO 6) */
#define PIN_LCD_MISO            -1      /* 单向显示无需读回 */
#define PIN_LCD_CS              7       /* 片选 CS (GPIO 7) */
#define PIN_LCD_DC              5       /* 命令/数据 DC (GPIO 5) */
#define PIN_LCD_RST             10      /* 复位 RST (GPIO 10) */
#define PIN_LCD_BL              1       /* 背光 BL (GPIO 1) */

/* 物理按键与指示 */
#define PIN_KEY_USER            9       /* 板载 BOOT 兜底按键 */
#define PIN_LED_STATUS          8       /* 板载状态指示灯 */

/* ==================== 编译期静态安全断言 (Static Assert) ==================== */
#if (PIN_LCD_CS == 8 || PIN_LCD_CS == 9 || PIN_LCD_DC == 8 || PIN_LCD_DC == 9)
    #error "[安全拦截] 严禁将 LCD CS 或 DC 引脚分配至 ESP32-C3 的 GPIO 8/9，否则会导致无法正常启动开机！"
#endif
