/**
 * @file board_esp32s3.h
 * @brief ESP32-S3 旗舰中控面板引脚画像 (支持高刷 SPI 或 8080 并口 86 盒面板)
 */

#pragma once

#define BOARD_CHIP_NAME         "ESP32-S3 Xtensa Dual-Core"

/* 总线选择: 1=高频 SPI, 2=8080 并口 (8位/16位) */
#define BOARD_BUS_TYPE_SPI      1
#define BOARD_BUS_TYPE_I8080    2

#define BOARD_BUS_CURRENT       BOARD_BUS_TYPE_SPI

#if (BOARD_BUS_CURRENT == BOARD_BUS_TYPE_SPI)
    #define PIN_LCD_SCLK        12
    #define PIN_LCD_MOSI        11
    #define PIN_LCD_MISO        -1
    #define PIN_LCD_CS          10
    #define PIN_LCD_DC          9
    #define PIN_LCD_RST         13
    #define PIN_LCD_BL          14
#else
    /* 8080 并口模式引脚 (适合 3.5寸~4.0寸 86盒屏幕) */
    #define PIN_LCD_D0          39
    #define PIN_LCD_D1          40
    #define PIN_LCD_D2          41
    #define PIN_LCD_D3          42
    #define PIN_LCD_D4          45
    #define PIN_LCD_D5          46
    #define PIN_LCD_D6          47
    #define PIN_LCD_D7          48
    #define PIN_LCD_WR          8
    #define PIN_LCD_RD          7
    #define PIN_LCD_CS          6
    #define PIN_LCD_DC          5
    #define PIN_LCD_RST         4
    #define PIN_LCD_BL          38
#endif

#define PIN_KEY_USER            0
#define PIN_LED_STATUS          48
