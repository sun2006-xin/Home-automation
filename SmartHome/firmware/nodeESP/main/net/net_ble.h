/**
 * @file net_ble.h
 * @brief BLE 近场直控 GATT 服务层 (Phone Direct Control without Router)
 */

#pragma once

#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化 NimBLE 协议栈并开启 GATT 服务与广播
 */
esp_err_t net_ble_init(void);

/**
 * @brief 向已连接的 BLE 客户端推送当前状态通知
 * @param pos 当前开度百分比 (0~100)
 */
void net_ble_notify_state(uint8_t pos);

#ifdef __cplusplus
}
#endif
