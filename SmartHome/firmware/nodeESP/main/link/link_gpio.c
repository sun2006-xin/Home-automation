#include "link.h"
#include "node_config.h"
#include "driver/drv_stepper.h"
#include "driver/drv_key.h"
#include "driver/drv_led.h"
#include "esp_log.h"
#include <string.h>
#include <stdio.h>

static const char *TAG = "LINK_GPIO";

static void handle_physical_key(key_event_t event) {
    if (event == KEY_EVENT_SHORT_PRESS) {
        // 短按：物理兜底翻转窗帘 (若开度>50% 则全关，否则全开)
        uint8_t cur = drv_stepper_get_pos();
        uint8_t target = (cur >= 50) ? 0 : 100;
        ESP_LOGW(TAG, "物理按键翻转窗帘: 当前=%d%% -> 目标=%d%%", cur, target);
        drv_stepper_set_target(target);
    } else if (event == KEY_EVENT_LONG_PRESS) {
        // 长按：急停
        ESP_LOGW(TAG, "物理按键急停触发");
        drv_stepper_stop();
    }
}

static esp_err_t link_gpio_init(void) {
    ESP_LOGI(TAG, "初始化 GPIO 本地被控硬件 (窗帘 C01)...");

    esp_err_t err = drv_stepper_init();
    if (err != ESP_OK) return err;

    err = drv_led_init();
    if (err != ESP_OK) return err;

    err = drv_key_init(handle_physical_key);
    if (err != ESP_OK) return err;

    return ESP_OK;
}

static esp_err_t link_gpio_apply(const char *cmd, int32_t param_val) {
    if (cmd == NULL) return ESP_ERR_INVALID_ARG;

    if (strcmp(cmd, "set") == 0) {
        return drv_stepper_set_target((uint8_t)param_val);
    } else if (strcmp(cmd, "stop") == 0) {
        drv_stepper_stop();
        return ESP_OK;
    } else if (strcmp(cmd, "toggle") == 0) {
        uint8_t cur = drv_stepper_get_pos();
        return drv_stepper_set_target((cur >= 50) ? 0 : 100);
    }

    ESP_LOGW(TAG, "未知的 link 命令: %s", cmd);
    return ESP_ERR_NOT_SUPPORTED;
}

static esp_err_t link_gpio_query(char *out_json, size_t max_len) {
    if (out_json == NULL || max_len == 0) return ESP_ERR_INVALID_ARG;

    uint8_t pos = drv_stepper_get_pos();
    bool moving = drv_stepper_is_moving();

    snprintf(out_json, max_len, "{\"pos\":%d,\"moving\":%s}",
             pos, moving ? "true" : "false");
    return ESP_OK;
}

static void link_gpio_poll(void) {
    if (drv_stepper_is_moving()) {
        drv_led_set_mode(LED_MODE_FAST_BLINK);
    } else {
        drv_led_set_mode(LED_MODE_SLOW_BLINK);
    }
}

const link_t link_gpio = {
    .init  = link_gpio_init,
    .apply = link_gpio_apply,
    .query = link_gpio_query,
    .poll  = link_gpio_poll,
};
