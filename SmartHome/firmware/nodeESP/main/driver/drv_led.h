/**
 * @file drv_led.h
 * @brief 节点状态指示灯驱动
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    LED_MODE_OFF = 0,
    LED_MODE_ON,
    LED_MODE_SLOW_BLINK, // 1s 慢闪 (未连接 / 待机)
    LED_MODE_FAST_BLINK, // 200ms 快闪 (电机运转中 / 配网中)
} led_mode_t;

esp_err_t drv_led_init(void);
void drv_led_set_mode(led_mode_t mode);

#ifdef __cplusplus
}
#endif
