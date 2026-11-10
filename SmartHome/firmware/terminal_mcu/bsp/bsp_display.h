/**
 * @file bsp_display.h
 * @brief MCU 终端通用显示屏硬件抽象接口 (基于 ESP-IDF v5.4 esp_lcd + LVGL)
 */

#pragma once

#include "bsp_display_config.h"
#include "esp_err.h"
#include "esp_lcd_panel_io.h"
#include "esp_lcd_panel_ops.h"
#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化显示屏控制器、背光控制并向 LVGL 注册显示驱动
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t bsp_display_init(void);

/**
 * @brief 调节显示屏背光亮度
 * @param brightness_percent 0~100 (0=熄屏, 100=全亮)
 */
void bsp_display_set_backlight(uint8_t brightness_percent);

/**
 * @brief 获取 LVGL 绑定的显示设备句柄
 * @return lv_disp_t*
 */
lv_disp_t *bsp_display_get_lv_disp(void);

#ifdef __cplusplus
}
#endif
