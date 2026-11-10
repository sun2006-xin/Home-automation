/**
 * @file board_stm32f4.h
 * @brief STM32F4 系列 (ARM Cortex-M4) 中控终端硬件画像
 *
 * 规范：
 * - 针对 STM32F401/F411/F407 架构；
 * - 硬件引脚映射与外设通道 (SPI1 / FSMC 并口) 严格绑定，杜绝引脚复用冲突。
 */

#pragma once

#define BOARD_CHIP_NAME         "STM32F4xx ARM Cortex-M4"

/* 总线选择: 1=硬件 SPI1 带 DMA, 2=FSMC 并口总线 (适合 F407 大板) */
#define BOARD_BUS_TYPE_SPI      1
#define BOARD_BUS_TYPE_FSMC     2

#define BOARD_BUS_CURRENT       BOARD_BUS_TYPE_SPI

#if (BOARD_BUS_CURRENT == BOARD_BUS_TYPE_SPI)
    /* 硬件 SPI1 引脚定义 (42MHz 高速时钟) */
    #define PIN_LCD_SCLK_PORT   GPIOA
    #define PIN_LCD_SCLK_PIN    5       /* PA5: SPI1_SCK */
    
    #define PIN_LCD_MOSI_PORT   GPIOA
    #define PIN_LCD_MOSI_PIN    7       /* PA7: SPI1_MOSI */
    
    #define PIN_LCD_CS_PORT     GPIOB
    #define PIN_LCD_CS_PIN      0       /* PB0: 片选 CS */
    
    #define PIN_LCD_DC_PORT     GPIOB
    #define PIN_LCD_DC_PIN      1       /* PB1: 数据/命令选择 DC */
    
    #define PIN_LCD_RST_PORT    GPIOB
    #define PIN_LCD_RST_PIN     2       /* PB2: 硬件复位 RST */
    
    #define PIN_LCD_BL_PORT     GPIOA
    #define PIN_LCD_BL_PIN      8       /* PA8: 背光控制 (TIM1_CH1 PWM) */

    #define LCD_SPI_INSTANCE    SPI1
    #define LCD_DMA_STREAM      DMA2_Stream3
#else
    /* FSMC 8080 并口内存映射基地址 (Bank 1, Sector 4, 16位宽) */
    #define FSMC_LCD_CMD_ADDR   ((uint32_t)0x6C000000)
    #define FSMC_LCD_DATA_ADDR  ((uint32_t)0x6C000002)
#endif

/* 物理兜底按键 (按键接 GND, 内部上拉) */
#define PIN_KEY_PORT            GPIOA
#define PIN_KEY_PIN             0       /* PA0: 用户按键 */
