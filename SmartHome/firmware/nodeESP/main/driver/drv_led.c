#include "drv_led.h"
#include "node_config.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

static led_mode_t s_mode = LED_MODE_SLOW_BLINK;

static void set_led(int on) {
    // ACTIVE_LEVEL=0 时，on=1 输出 0；on=0 输出 1
    gpio_set_level(CONFIG_LED_GPIO, on ? CONFIG_LED_ACTIVE_LEVEL : !CONFIG_LED_ACTIVE_LEVEL);
}

static void led_task(void *pvParameters) {
    int state = 0;
    while (1) {
        switch (s_mode) {
            case LED_MODE_OFF:
                set_led(0);
                vTaskDelay(pdMS_TO_TICKS(100));
                break;
            case LED_MODE_ON:
                set_led(1);
                vTaskDelay(pdMS_TO_TICKS(100));
                break;
            case LED_MODE_SLOW_BLINK:
                state = !state;
                set_led(state);
                vTaskDelay(pdMS_TO_TICKS(1000));
                break;
            case LED_MODE_FAST_BLINK:
                state = !state;
                set_led(state);
                vTaskDelay(pdMS_TO_TICKS(200));
                break;
        }
    }
}

esp_err_t drv_led_init(void) {
    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << CONFIG_LED_GPIO),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&io_conf);
    if (err != ESP_OK) return err;

    set_led(0);
    xTaskCreate(led_task, "led_task", 1536, NULL, 2, NULL);
    return ESP_OK;
}

void drv_led_set_mode(led_mode_t mode) {
    s_mode = mode;
}
