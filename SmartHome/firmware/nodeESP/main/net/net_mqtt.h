/**
 * @file net_mqtt.h
 * @brief ESP32-C3 本地 MQTT 通信客户端 (自动发现、LWT 遗嘱、指令监听与状态发布)
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化 MQTT 客户端并连接本地 Broker
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t net_mqtt_init(void);

/**
 * @brief 发布当前窗帘开度状态 (retain=1, QoS=1)
 * @param pos 当前开度 (0~100)
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t net_mqtt_publish_state(uint8_t pos);

/**
 * @brief 发布节点自动发现声明包至 sh/{home}/_discovery
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t net_mqtt_publish_discovery(void);

/**
 * @brief 查询 MQTT 连接状态
 * @return true 已连接到 Broker
 * @return false 离线
 */
bool net_mqtt_is_connected(void);

#ifdef __cplusplus
}
#endif
