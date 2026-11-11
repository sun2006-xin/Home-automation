#include "drv_key.h"
#include "node_config.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "DRV_KEY";
static key_callback_t s_callback = NULL;

static void key_scan_task(void *pvParameters) {
    int last_level = 1;
    uint32_t press_start_ms = 0;
    bool is_pressed = false;

    while (1) {
        int level = gpio_get_level(CONFIG_KEY_GPIO);

        if (level == 0 && last_level == 1) {
            // 下降沿：按下
            vTaskDelay(pdMS_TO_TICKS(20)); // 消抖
            if (gpio_get_level(CONFIG_KEY_GPIO) == 0) {
                is_pressed = true;
                press_start_ms = xTaskGetTickCount() * portTICK_PERIOD_MS;
            }
        } else if (level == 1 && last_level == 0) {
            // 上升沿：释放
            if (is_pressed) {
                uint32_t duration_ms = (xTaskGetTickCount() * portTICK_PERIOD_MS) - press_start_ms;
                is_pressed = false;

                if (duration_ms > 3000) {
                    ESP_LOGW(TAG, "物理按键长按触发 (>3s)");
                    if (s_callback) s_callback(KEY_EVENT_LONG_PRESS);
                } else if (duration_ms > 50) {
                    ESP_LOGI(TAG, "物理按键短按触发 (%ld ms)", duration_ms);
                    if (s_callback) s_callback(KEY_EVENT_SHORT_PRESS);
                }
            }
        }

        last_level = level;
        vTaskDelay(pdMS_TO_TICKS(20));
    }
}

esp_err_t drv_key_init(key_callback_t cb) {
    s_callback = cb;

    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << CONFIG_KEY_GPIO),
        .mode = GPIO_MODE_INPUT,
        .pull_up_en = GPIO_PULLUP_ENABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&io_conf);
    if (err != ESP_OK) return err;

    /* 回调链路内含 ESP_LOG 输出，Xtensa 架构需 >= 3072B 栈空间 */
    xTaskCreate(key_scan_task, "key_scan_task", 3072, NULL, 4, NULL);
    return ESP_OK;
}
