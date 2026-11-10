/**
 * @file drv_key.h
 * @brief 本地物理按键防抖与事件处理层 (Physical Fail-safe Key)
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    KEY_EVENT_NONE = 0,
    KEY_EVENT_SHORT_PRESS, // 短按：开关/急停
    KEY_EVENT_LONG_PRESS,  // 长按(>3s)：进入配网/重置
} key_event_t;

typedef void (*key_callback_t)(key_event_t event);

/**
 * @brief 初始化物理按键输入并启动防抖检测任务
 */
esp_err_t drv_key_init(key_callback_t cb);

#ifdef __cplusplus
}
#endif
