/**
 * @file ui_theme_tokens.h
 * @brief MCU 中控终端响应式设计令牌 (自适应栅格、动态字号与温暖家居配色)
 *
 * 规范：与手机终端保持 100% 视觉设计语言一致 (Warm Japandi Style)
 */

#pragma once

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ==================== 1. 视口规格动态判定 ==================== */
/* 小屏: 240x240 (圆屏旋钮/桌面小方块) */
#define UI_IS_SMALL_SCREEN      (LV_HOR_RES <= 260)

/* 中屏: 320x240 (2.4~2.8寸标准横屏) */
#define UI_IS_MEDIUM_SCREEN     (LV_HOR_RES > 260 && LV_HOR_RES <= 400)

/* 大屏: 480x320 / 480x480 (86盒墙面中控面板) */
#define UI_IS_LARGE_SCREEN      (LV_HOR_RES > 400)

/* ==================== 2. 温暖原木家居调色板 (Warm Japandi Palette) ==================== */
#define UI_COLOR_BG             lv_color_hex(0x1A120B)  /* 深暖色背景底色 */
#define UI_COLOR_CARD_BG        lv_color_hex(0x281E16)  /* 暖咖色半透卡片背景 */
#define UI_COLOR_CARD_ACTIVE    lv_color_hex(0x35251B)  /* 卡片高亮聚焦底色 */
#define UI_COLOR_CARD_BORDER    lv_color_hex(0x4E3B2C)  /* 卡片微暖边框 */

#define UI_COLOR_BTN_NORMAL     lv_color_hex(0x382A20)  /* 按键普通底色 */
#define UI_COLOR_BTN_ACTIVE     lv_color_hex(0xD86A38)  /* 暖琥珀活力高亮按键 */
#define UI_COLOR_BTN_BORDER     lv_color_hex(0x563E2D)  /* 按键边框 */

#define UI_COLOR_TEXT_PRIMARY   lv_color_hex(0xFFF7F0)  /* 羊脂暖白主文字 */
#define UI_COLOR_TEXT_SECONDARY lv_color_hex(0xCEBAAA)  /* 暖米灰次级文字 */
#define UI_COLOR_TEXT_MUTED     lv_color_hex(0x8D7B6D)  /* 辅助弱文字 */

#define UI_COLOR_ACCENT_AMBER   lv_color_hex(0xF2A359)  /* 温暖琥珀色点缀 */
#define UI_COLOR_ACCENT_GREEN   lv_color_hex(0x68B984)  /* 森林绿在线状态 */

/* ==================== 3. 动态响应式尺寸与布局令牌 ==================== */
/* 卡片宽度百分比:
 *  - 小屏/窄屏: 占屏幕 96% 宽度 (单列自顶向下堆叠)
 *  - 中屏/大屏: 占屏幕 48% 宽度 (两列流式自动排布)
 */
#define TOKEN_CARD_WIDTH_PCT    (UI_IS_SMALL_SCREEN ? lv_pct(96) : lv_pct(48))

/* 动态栅格内边距 (Padding) */
#define TOKEN_PADDING_SCREEN    (UI_IS_SMALL_SCREEN ? 4 : (UI_IS_MEDIUM_SCREEN ? 8 : 14))
#define TOKEN_PADDING_CARD      (UI_IS_SMALL_SCREEN ? 6 : (UI_IS_MEDIUM_SCREEN ? 10 : 14))
#define TOKEN_GUTTER            (UI_IS_SMALL_SCREEN ? 4 : (UI_IS_MEDIUM_SCREEN ? 8 : 12))
#define TOKEN_RADIUS_CARD       (UI_IS_SMALL_SCREEN ? 8 : 14)
#define TOKEN_RADIUS_BTN        (UI_IS_SMALL_SCREEN ? 6 : 10)

/* 动态字号令牌 (根据屏幕像素密度自适应) */
#define TOKEN_FONT_TITLE        (UI_IS_LARGE_SCREEN ? &lv_font_montserrat_20 : \
                                (UI_IS_MEDIUM_SCREEN ? &lv_font_montserrat_14 : &lv_font_montserrat_12))

#define TOKEN_FONT_BODY         (UI_IS_LARGE_SCREEN ? &lv_font_montserrat_16 : \
                                (UI_IS_MEDIUM_SCREEN ? &lv_font_montserrat_12 : &lv_font_montserrat_10))

#define TOKEN_FONT_CAPTION      (UI_IS_LARGE_SCREEN ? &lv_font_montserrat_12 : &lv_font_montserrat_10)

#ifdef __cplusplus
}
#endif
