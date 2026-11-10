/**
 * @file drv_stepper.h
 * @brief 28BYJ-48 步进电机 + ULN2003 四相八拍高精度驱动层
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 初始化步进电机 GPIO 与任务
 * @return esp_err_t ESP_OK 成功
 */
esp_err_t drv_stepper_init(void);

/**
 * @brief 设置目标开合百分比 (0=全关, 100=全开)
 * @param pos_percent 0 ~ 100
 * @return esp_err_t
 */
esp_err_t drv_stepper_set_target(uint8_t pos_percent);

/**
 * @brief 获取当前实际物理位置百分比 (0 ~ 100)
 */
uint8_t drv_stepper_get_pos(void);

/**
 * @brief 电机是否正在运转
 */
bool drv_stepper_is_moving(void);

/**
 * @brief 紧急制动并切断线圈强电，防止发热
 */
void drv_stepper_stop(void);

#ifdef __cplusplus
}
#endif
