/**
 * @file app_main.c
 * @brief 分布式智能家居节点主入口 (ESP32-C3 Phase M1)
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "nvs_flash.h"
#include "esp_log.h"
#include "node_config.h"
#include "link/link.h"
#include "net/net_ble.h"

static const char *TAG = "APP_MAIN";

void app_main(void) {
    ESP_LOGI(TAG, "==================================================");
    ESP_LOGI(TAG, "  分布式智慧家居 · C3 独立节点固件 (%s)", NODE_FW_VERSION);
    ESP_LOGI(TAG, "  设备 ID: [%s] | 物理角色: [%s] | 归属: [%s]",
             NODE_DEVICE_ID, NODE_DEVICE_NAME, NODE_DEVICE_ROOM);
    ESP_LOGI(TAG, "==================================================");

    // 1. 初始化 NVS 存储
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    // 2. 初始化硬件 link 层 (步进电机驱动 + 物理按键 + 状态指示灯)
    ESP_ERROR_CHECK(link_gpio.init());

    // 3. 启动 BLE 近场直控 GATT 协议栈 (M1 验收硬指标：无需 WiFi 与云端即可手机直控)
    ESP_ERROR_CHECK(net_ble_init());

    ESP_LOGI(TAG, "节点核心系统启动完成，进入主调度监控循环...");

    // 4. 主系统周期轮询与健康看门狗
    while (1) {
        link_gpio.poll();
        vTaskDelay(pdMS_TO_TICKS(100));
    }
}
