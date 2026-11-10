/**
 * @file bsp_display_config.h
 * @brief MCU 中控终端显示屏硬件配置文件 (用户换屏唯一需要修改的文件)
 *
 * 架构规范：
 * 1. 支持任意分辨率（240x240 圆屏/方屏、320x240、480x320、800x480）；
 * 2. 支持常见驱动芯片 (ST7789, ILI9341, ST7796, GC9A01)；
 * 3. 驱动层与上层 UI 逻辑彻底解耦，换屏无需改动任何 UI 业务代码。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ==================== 1. 显示屏物理规格配置 ==================== */
/* 常用预设:
 *  - 240x240: 1.28寸/1.54寸圆屏旋钮/桌面方屏
 *  - 320x240: 2.4寸/2.8寸标准彩屏 (缺省推荐横屏)
 *  - 480x320: 3.5寸/4.0寸 86盒标准墙壁中控屏
 *  - 800x480: 7.0寸桌面大屏终端
 */
#define BSP_DISPLAY_HOR_RES         320     /* 屏幕物理水平像素宽度 */
#define BSP_DISPLAY_VER_RES         240     /* 屏幕物理垂直像素高度 */
#define BSP_DISPLAY_ROTATION_DEG    90      /* 旋转角度: 0, 90(标准横屏), 180, 270 */

/* 驱动芯片选择: 1=ST7789, 2=ILI9341, 3=ST7796, 4=GC9A01 */
#define BSP_DISPLAY_DRIVER_ST7789   1
#define BSP_DISPLAY_DRIVER_ILI9341  2
#define BSP_DISPLAY_DRIVER_ST7796   3
#define BSP_DISPLAY_DRIVER_GC9A01   4

#define BSP_DISPLAY_DRIVER_TYPE     BSP_DISPLAY_DRIVER_ST7789

/* ==================== 2. SPI 通信总线引脚定义 (ESP32-S3 / C3 兼容) ==================== */
#define BSP_SPI_HOST_ID             SPI2_HOST

#define BSP_PIN_NUM_SCLK            18      /* SPI 时钟引脚 */
#define BSP_PIN_NUM_MOSI            19      /* SPI 数据输出引脚 */
#define BSP_PIN_NUM_MISO            -1      /* 单向屏无需读数据 */

#define BSP_PIN_NUM_LCD_CS          5       /* 片选信号 CS */
#define BSP_PIN_NUM_LCD_DC          4       /* 数据/命令选择 D/C */
#define BSP_PIN_NUM_LCD_RST         2       /* 复位信号 RST (-1 表示由外部硬件上电复位) */
#define BSP_PIN_NUM_BK_LIGHT        15      /* 背光控制引脚 BL */
#define BSP_LCD_BK_LIGHT_ON_LEVEL   1       /* 1=高电平点亮, 0=低电平点亮 */

/* SPI 传输时钟频率 (常见 40MHz ~ 80MHz) */
#define BSP_LCD_PIXEL_CLOCK_HZ      (40 * 1000 * 1000)

/* ==================== 3. 内存与双缓冲配置 ==================== */
/* DMA 刷新单行缓冲区行数 (行数越大刷新越平滑，消耗 SRAM 增多；320宽屏取 20~40 行为佳) */
#define BSP_LCD_DMA_BUFFER_LINES    20

#ifdef __cplusplus
}
#endif
