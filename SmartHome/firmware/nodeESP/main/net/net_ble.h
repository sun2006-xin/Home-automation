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

#ifdef __cplusplus
}
#endif
