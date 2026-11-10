#include "drv_stepper.h"
#include "node_config.h"
#include "driver/gpio.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/semphr.h"
#include "esp_log.h"
#include "esp_rom_sys.h"

static const char *TAG = "DRV_STEPPER";

// 四相八拍励磁真值表 (A, B, C, D)
static const uint8_t s_step_table[8][4] = {
    {1, 0, 0, 0}, // 拍 1: A
    {1, 1, 0, 0}, // 拍 2: AB
    {0, 1, 0, 0}, // 拍 3: B
    {0, 1, 1, 0}, // 拍 4: BC
    {0, 0, 1, 0}, // 拍 5: C
    {0, 0, 1, 1}, // 拍 6: CD
    {0, 0, 0, 1}, // 拍 7: D
    {1, 0, 0, 1}, // 拍 8: DA
};

static int32_t s_current_step = 0;
static int32_t s_target_step = 0;
static uint8_t s_beat_index = 0;
static bool s_is_moving = false;
static SemaphoreHandle_t s_mutex = NULL;
static TaskHandle_t s_task_handle = NULL;

static void set_coils(uint8_t a, uint8_t b, uint8_t c, uint8_t d) {
    gpio_set_level(CONFIG_STEPPER_PIN_IN1, a);
    gpio_set_level(CONFIG_STEPPER_PIN_IN2, b);
    gpio_set_level(CONFIG_STEPPER_PIN_IN3, c);
    gpio_set_level(CONFIG_STEPPER_PIN_IN4, d);
}

static void release_coils(void) {
    set_coils(0, 0, 0, 0);
}

static void stepper_task(void *pvParameters) {
    ESP_LOGI(TAG, "步进电机驱动任务已就绪 (IN1=%d, IN2=%d, IN3=%d, IN4=%d)",
             CONFIG_STEPPER_PIN_IN1, CONFIG_STEPPER_PIN_IN2,
             CONFIG_STEPPER_PIN_IN3, CONFIG_STEPPER_PIN_IN4);

    while (1) {
        int32_t cur = 0;
        int32_t tgt = 0;

        if (xSemaphoreTake(s_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            cur = s_current_step;
            tgt = s_target_step;
            xSemaphoreGive(s_mutex);
        }

        if (cur != tgt) {
            s_is_moving = true;

            // 确定方向
            if (cur < tgt) {
                // 正转 (开窗)
                s_beat_index = (s_beat_index + 1) & 0x07;
                cur++;
            } else {
                // 反转 (关窗)
                s_beat_index = (s_beat_index - 1) & 0x07;
                cur--;
            }

            // 输出脉冲
            set_coils(s_step_table[s_beat_index][0],
                      s_step_table[s_beat_index][1],
                      s_step_table[s_beat_index][2],
                      s_step_table[s_beat_index][3]);

            if (xSemaphoreTake(s_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
                s_current_step = cur;
                xSemaphoreGive(s_mutex);
            }

            // 步进间隔 (1.5ms)
            vTaskDelay(pdMS_TO_TICKS(2));
        } else {
            if (s_is_moving) {
                s_is_moving = false;
                release_coils(); // 到位断电，释放发热线圈
                ESP_LOGI(TAG, "电机运行到位: %ld 步 (%d%%)", s_current_step, drv_stepper_get_pos());
            }
            vTaskDelay(pdMS_TO_TICKS(50));
        }
    }
}

esp_err_t drv_stepper_init(void) {
    if (s_mutex == NULL) {
        s_mutex = xSemaphoreCreateMutex();
    }

    gpio_config_t io_conf = {
        .pin_bit_mask = (1ULL << CONFIG_STEPPER_PIN_IN1) |
                        (1ULL << CONFIG_STEPPER_PIN_IN2) |
                        (1ULL << CONFIG_STEPPER_PIN_IN3) |
                        (1ULL << CONFIG_STEPPER_PIN_IN4),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE,
    };
    esp_err_t err = gpio_config(&io_conf);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "GPIO 配置失败: %d", err);
        return err;
    }

    release_coils();

    if (s_task_handle == NULL) {
        xTaskCreate(stepper_task, "stepper_task", 3072, NULL, 5, &s_task_handle);
    }

    return ESP_OK;
}

esp_err_t drv_stepper_set_target(uint8_t pos_percent) {
    if (pos_percent > 100) pos_percent = 100;

    int32_t target_steps = (int32_t)((pos_percent / 100.0f) * CONFIG_STEPPER_TOTAL_STEPS);

    if (xSemaphoreTake(s_mutex, pdMS_TO_TICKS(50)) == pdTRUE) {
        s_target_step = target_steps;
        xSemaphoreGive(s_mutex);
        ESP_LOGI(TAG, "设定目标开度: %d%% (%ld 步)", pos_percent, target_steps);
        return ESP_OK;
    }

    return ESP_ERR_TIMEOUT;
}

uint8_t drv_stepper_get_pos(void) {
    int32_t cur = 0;
    if (xSemaphoreTake(s_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
        cur = s_current_step;
        xSemaphoreGive(s_mutex);
    }

    int32_t pct = (cur * 100) / CONFIG_STEPPER_TOTAL_STEPS;
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    return (uint8_t)pct;
}

bool drv_stepper_is_moving(void) {
    return s_is_moving;
}

void drv_stepper_stop(void) {
    if (xSemaphoreTake(s_mutex, pdMS_TO_TICKS(50)) == pdTRUE) {
        s_target_step = s_current_step;
        xSemaphoreGive(s_mutex);
    }
    release_coils();
    s_is_moving = false;
    ESP_LOGW(TAG, "电机已执行急停");
}
