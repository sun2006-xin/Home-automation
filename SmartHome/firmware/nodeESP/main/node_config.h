/**
 * @file node_config.h
 * @brief 分布式智能节点唯一硬件与角色配置文件 (One firmware, multiple nodes)
 *
 * 架构规范：
 * 1. 同一份固件工程烧录全屋所有 ESP32-C3 节点；
 * 2. 节点的电器类型、硬件引脚与通信 ID 唯一在此文件定义；
 * 3. 本配置为 Phase M1：【C01 窗帘电机物理验证节点】。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ==================== 1. 设备身份定义 ==================== */
#define NODE_DEVICE_ID          "C01"
#define NODE_DEVICE_NAME        "客厅主窗帘"
#define NODE_DEVICE_ROOM        "客厅"
#define NODE_FW_VERSION         "v1.0.0"

/* 设备能力类型: 1=SWITCH(开关/灯), 2=COVER(窗帘/行程), 3=CLIMATE(温控), 4=HEATER(加热/插座) */
#define NODE_TYPE_COVER         1

/* BLE 广播设备名称 (手机无需局域网即可近场搜到并控制) */
#define NODE_BLE_DEVICE_NAME    "SH_CURTAIN_C01"

/* ==================== 2. GPIO 引脚规划 (ESP32-C3 SuperMini) ==================== */
/* 28BYJ-48 步进电机驱动板 (ULN2003 四相输入) */
#define CONFIG_STEPPER_PIN_IN1  4   /* GPIO 4: A 相 */
#define CONFIG_STEPPER_PIN_IN2  5   /* GPIO 5: B 相 */
#define CONFIG_STEPPER_PIN_IN3  6   /* GPIO 6: C 相 */
#define CONFIG_STEPPER_PIN_IN4  7   /* GPIO 7: D 相 */

/* 本地物理兜底按键 (带内部上拉，低电平有效) */
#define CONFIG_KEY_GPIO         9   /* 板载 BOOT 键 / 外部按键 */

/* 状态指示 LED (C3 SuperMini 板载蓝色 LED 为 GPIO 8，低电平点亮) */
#define CONFIG_LED_GPIO         8
#define CONFIG_LED_ACTIVE_LEVEL 0   /* 低电平点亮 */

/* ==================== 3. 步进电机物理行程参数 (28BYJ-48 + 1:64 减速箱) ==================== */
/* 4相8拍半步驱动模式下，输出轴旋转 1 圈约为 4096 步 */
#define CONFIG_STEPPER_TOTAL_STEPS  4096   /* 0% (全关) 到 100% (全开) 对应总步数 */
#define CONFIG_STEP_INTERVAL_US     1500   /* 脉冲间隔微秒 (1.5ms 运行平稳且力矩充沛) */

#ifdef __cplusplus
}
#endif
