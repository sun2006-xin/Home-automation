/**
 * @file main.c
 * @brief MCU 智慧家庭自适应中控终端主入口
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_timer.h"
#include "esp_log.h"
#include "bsp_display.h"
#include "ui_adaptive_deck.h"

static const char *TAG = "TERMINAL_MCU";

static void lv_tick_task(void *arg) {
    (void)arg;
    lv_tick_inc(5); // 告知 LVGL 过去了 5 毫秒
}

void app_main(void) {
    ESP_LOGI(TAG, "==================================================");
    ESP_LOGI(TAG, "  分布式智慧家庭 · MCU 独立中控终端启动");
    ESP_LOGI(TAG, "  多屏自适应引擎: Flexbox 弹性流 + 响应式设计令牌");
    ESP_LOGI(TAG, "==================================================");

    // 1. 初始化 LVGL 核心图形库
    lv_init();

    // 2. 初始化硬件屏幕控制器并注册 LVGL 显存双缓冲
    esp_err_t ret = bsp_display_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "显示屏硬件初始化失败: %d", ret);
        return;
    }

    // 3. 配置高精度定时器喂给 LVGL Tick (每 5ms 一次)
    const esp_timer_create_args_t lv_tick_timer_args = {
        .callback = &lv_tick_task,
        .name = "lv_tick_timer"
    };
    esp_timer_handle_t lv_tick_timer = NULL;
    esp_timer_create(&lv_tick_timer_args, &lv_tick_timer);
    esp_timer_start_periodic(lv_tick_timer, 5000); // 5000us = 5ms

    // 4. 创建响应式全屋智能中控 Deck 界面
    ui_adaptive_deck_create();

    ESP_LOGI(TAG, "中控中枢 UI 渲染就绪，进入 GUI 调度循环...");

    // 5. LVGL 核心调度循环
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(10));
        lv_timer_handler();
    }
}
