/**
 * @file ui_adaptive_deck.h
 * @brief MCU 终端自适应卡片中控界面 (支持 240/320/480 任意分辨率自动响应式排版)
 */

#pragma once

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief 构建自适应全屋智能中控界面
 *
 * 核心机制：
 * 1. 采用 LV_FLEX_FLOW_ROW_WRAP 弹性盒子自动流式排版；
 * 2. 无论屏幕为 240x240、320x240 还是 480x320，卡片列数与尺寸自动伸缩；
 * 3. 包含顶栏状态、双层分类卡片流、以及底栏房间快捷切换药丸条。
 */
void ui_adaptive_deck_create(void);

/**
 * @brief 更新指定电器的运行状态
 * @param device_id 设备标识 (如 "C01", "L01")
 * @param state_val 状态数值 (如开度 0~100，或开关 0/1)
 */
void ui_adaptive_deck_update_device(const char *device_id, int state_val);

#ifdef __cplusplus
}
#endif
