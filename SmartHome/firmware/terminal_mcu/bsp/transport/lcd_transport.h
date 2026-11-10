/**
 * @file lcd_transport.h
 * @brief 屏幕底层物理总线抽象契约 (LCD Transport Contract)
 *
 * 核心解耦架构：
 * 1. 彻底抹平 SPI、8080 并口、FSMC、QSPI 等各 MCU 专属硬件外设差异；
 * 2. 无论在 ESP32 还是 STM32，LVGL 图形引擎只调用本契约暴露的 3 个核心接口；
 * 3. 换 MCU 时只需提供该芯片对应的 transport 实现，业务 UI 与驱动层一字不改。
 */

#pragma once

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*lcd_trans_done_cb_t)(void *user_ctx);

typedef struct {
    /**
     * @brief 传输层总线名称 (如 "ESP32_SPI_DMA" / "STM32_FSMC_8080")
     */
    const char *name;

    /**
     * @brief 初始化底层通信总线与 DMA 管道
     */
    int (*init)(void);

    /**
     * @brief 发送单字节或双字节 LCD 控制寄存器命令字 (DC=0)
     */
    void (*write_cmd)(uint8_t cmd);

    /**
     * @brief 发送常规参数数据流 (DC=1)
     */
    void (*write_data)(const uint8_t *data, size_t len);

    /**
     * @brief 异步将 LVGL 渲染矩形视口通过 DMA 极速刷入屏幕 (非阻塞)
     * @param x1 矩形起始 X
     * @param y1 矩形起始 Y
     * @param x2 矩形结束 X
     * @param y2 矩形结束 Y
     * @param color_map 16位 RGB565 像素连续显存
     * @param on_done_cb DMA 发送完成硬件中断回调 (用于通知 LVGL flush_ready)
     * @param user_ctx 用户上下文指针
     */
    void (*draw_bitmap_async)(int x1, int y1, int x2, int y2,
                              const void *color_map,
                              lcd_trans_done_cb_t on_done_cb,
                              void *user_ctx);
} lcd_transport_t;

/* 获取当前硬件平台激活的传输层实例 */
const lcd_transport_t *lcd_transport_get_active(void);

#ifdef __cplusplus
}
#endif
