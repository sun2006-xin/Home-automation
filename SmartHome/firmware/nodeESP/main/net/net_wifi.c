/**
 * @file net_wifi.c
 * @brief ESP32-C3 WiFi STA 实现 (带指数退避重连与状态灯联动)
 */

#include "net_wifi.h"
#include "node_config.h"
#include "driver/drv_led.h"
#include "esp_wifi.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/timers.h"
#include <string.h>

static const char *TAG = "NET_WIFI";

/* 静态连接状态与 IP 缓存 */
static bool s_is_connected = false;
static char s_ip_addr[16] = "0.0.0.0";

/* 指数退避重连参数 (秒) */
#define RETRY_INTERVAL_MIN_SEC  2
#define RETRY_INTERVAL_MAX_SEC  60
static uint32_t s_retry_interval_sec = RETRY_INTERVAL_MIN_SEC;
static TimerHandle_t s_reconnect_timer = NULL;

static void reconnect_timer_cb(TimerHandle_t xTimer) {
    ESP_LOGI(TAG, "执行 WiFi 重连尝试 (当前间隔: %lu 秒)...", s_retry_interval_sec);
    esp_wifi_connect();
}

static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data) {
    if (event_base == WIFI_EVENT) {
        switch (event_id) {
            case WIFI_EVENT_STA_START:
                ESP_LOGI(TAG, "WiFi STA 启动成功，发起首次连接 -> SSID: [%s]", CONFIG_WIFI_SSID);
                drv_led_set_mode(LED_MODE_SLOW_BLINK);
                esp_wifi_connect();
                break;

            case WIFI_EVENT_STA_DISCONNECTED:
                s_is_connected = false;
                drv_led_set_mode(LED_MODE_FAST_BLINK);
                ESP_LOGW(TAG, "WiFi 掉线/连接失败，将在 %lu 秒后重连...", s_retry_interval_sec);

                /* 启动重连定时器 */
                if (s_reconnect_timer != NULL) {
                    xTimerChangePeriod(s_reconnect_timer, pdMS_TO_TICKS(s_retry_interval_sec * 1000), 0);
                    xTimerStart(s_reconnect_timer, 0);
                }

                /* 指数退避翻倍，封顶 60s */
                s_retry_interval_sec *= 2;
                if (s_retry_interval_sec > RETRY_INTERVAL_MAX_SEC) {
                    s_retry_interval_sec = RETRY_INTERVAL_MAX_SEC;
                }
                break;

            default:
                break;
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        snprintf(s_ip_addr, sizeof(s_ip_addr), IPSTR, IP2STR(&event->ip_info.ip));
        s_is_connected = true;
        s_retry_interval_sec = RETRY_INTERVAL_MIN_SEC; /* 复位退避间隔 */

        if (s_reconnect_timer != NULL) {
            xTimerStop(s_reconnect_timer, 0);
        }

        ESP_LOGI(TAG, "WiFi 已连接并成功获取 IP 地址: %s", s_ip_addr);
        drv_led_set_mode(LED_MODE_ON);
    }
}

esp_err_t net_wifi_init(void) {
    /* 1. 初始化 TCP/IP 适配层 */
    esp_err_t ret = esp_netif_init();
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
        ESP_LOGE(TAG, "esp_netif_init 失败: %d", ret);
        return ret;
    }

    /* 2. 创建默认系统事件循环 */
    ret = esp_event_loop_create_default();
    if (ret != ESP_OK && ret != ESP_ERR_INVALID_STATE) {
        ESP_LOGE(TAG, "创建默认事件循环失败: %d", ret);
        return ret;
    }

    /* 3. 创建默认 WiFi STA 接口 */
    esp_netif_create_default_wifi_sta();

    /* 4. 创建一次性重连定时器 */
    if (s_reconnect_timer == NULL) {
        s_reconnect_timer = xTimerCreate("wifi_reconnect_tmr",
                                         pdMS_TO_TICKS(RETRY_INTERVAL_MIN_SEC * 1000),
                                         pdFALSE,
                                         NULL,
                                         reconnect_timer_cb);
    }

    /* 5. 初始化 WiFi 驱动 */
    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ret = esp_wifi_init(&cfg);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "esp_wifi_init 失败: %d", ret);
        return ret;
    }

    /* 6. 注册 WiFi 与 IP 事件监听 */
    esp_event_handler_instance_register(WIFI_EVENT, ESP_EVENT_ANY_ID,
                                        &wifi_event_handler, NULL, NULL);
    esp_event_handler_instance_register(IP_EVENT, IP_EVENT_STA_GOT_IP,
                                        &wifi_event_handler, NULL, NULL);

    /* 7. 配置 WiFi 凭据 */
    wifi_config_t wifi_cfg = {0};
    strncpy((char *)wifi_cfg.sta.ssid, CONFIG_WIFI_SSID, sizeof(wifi_cfg.sta.ssid) - 1);
    strncpy((char *)wifi_cfg.sta.password, CONFIG_WIFI_PASSWORD, sizeof(wifi_cfg.sta.password) - 1);
    wifi_cfg.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;

    ret = esp_wifi_set_mode(WIFI_MODE_STA);
    if (ret != ESP_OK) return ret;

    ret = esp_wifi_set_config(WIFI_IF_STA, &wifi_cfg);
    if (ret != ESP_OK) return ret;

    /* 8. 启动 WiFi 协议栈 */
    ret = esp_wifi_start();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "esp_wifi_start 失败: %d", ret);
        return ret;
    }

    ESP_LOGI(TAG, "WiFi 模块初始化完成 (SSID: %s)", CONFIG_WIFI_SSID);
    return ESP_OK;
}

bool net_wifi_is_connected(void) {
    return s_is_connected;
}

void net_wifi_get_ip_str(char *buf, size_t max_len) {
    if (buf == NULL || max_len == 0) return;
    strncpy(buf, s_ip_addr, max_len - 1);
    buf[max_len - 1] = '\0';
}
