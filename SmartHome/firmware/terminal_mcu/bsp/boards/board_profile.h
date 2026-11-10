/**
 * @file board_profile.h
 * @brief MCU 终端多硬件平台核心选择器 (换 MCU 只需在这里切换一行宏)
 *
 * 核心机制：
 * 1. 隔离 ESP32、STM32 等异构芯片的底层引脚差异；
 * 2. 自动载入对应的板级画像 (Board Profile)；
 * 3. 编译期进行引脚冲突与合法性静态断言。
 */

#pragma once

/* ==================== 1. 支持的硬件板级型号列表 ==================== */
#define BOARD_TARGET_ESP32C3_SUPERMINI  1   /* ESP32-C3 极简超迷你终端 */
#define BOARD_TARGET_ESP32S3_DEVKIT     2   /* ESP32-S3 双核旗舰中控屏 */
#define BOARD_TARGET_STM32F401_BLACKPILL 3  /* STM32F401/F411 经典黑丸板 */
#define BOARD_TARGET_STM32F407_DEV      4   /* STM32F407 带 FSMC 8080 并口板 */

/* ==================== 2. 当前编译目标板选择 (唯一的选择宏) ==================== */
#ifndef TARGET_BOARD
    #define TARGET_BOARD    BOARD_TARGET_ESP32C3_SUPERMINI
#endif

/* ==================== 3. 动态加载板级引脚与总线画像 ==================== */
#if (TARGET_BOARD == BOARD_TARGET_ESP32C3_SUPERMINI)
    #include "board_esp32c3.h"
#elif (TARGET_BOARD == BOARD_TARGET_ESP32S3_DEVKIT)
    #include "board_esp32s3.h"
#elif (TARGET_BOARD == BOARD_TARGET_STM32F401_BLACKPILL || TARGET_BOARD == BOARD_TARGET_STM32F407_DEV)
    #include "board_stm32f4.h"
#else
    #error "[架构错误] 未知的 TARGET_BOARD 目标板定义，请检查 board_profile.h！"
#endif
