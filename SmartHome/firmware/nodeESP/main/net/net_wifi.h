/**
 * @file net_wifi.h
 * @brief ESP32-C3 WiFi STA 自动连接与故障指数退避重连模块
 */

#pragma once

#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化 WiFi STA 模式并开始异步连接
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t net_wifi_init(void);

/**
 * @brief 查询当前 WiFi STA 连接状态
 * @return true 已获取 IP 地址并在线
 * @return false 离线或重连中
 */
bool net_wifi_is_connected(void);

/**
 * @brief 获取本机分配到的 IP 地址字符串
 * @param buf 存储 IP 的缓冲区 (建议长度 >= 16)
 * @param max_len 缓冲区最大容量
 */
void net_wifi_get_ip_str(char *buf, size_t max_len);

#ifdef __cplusplus
}
#endif
