/**
 * @file link.h
 * @brief 节点硬件抽象能力层 (Link Layer Interface)
 *
 * 核心解耦架构：
 * 1. link 抽象了"物理被控对象"的控制与查询接口；
 * 2. 纯节点使用 `link_gpio` (C3 直接控制 GPIO 继电器/步进电机)；
 * 3. 51 终端形态使用 `link_serial` (C3 通过 UART 向 51 转发指令)；
 * 4. 上层网络协议 (BLE, MQTT, HTTP) 仅对接 link，不直接触碰底层 GPIO。
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include "esp_err.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    /**
     * @brief 初始化底层硬件
     */
    esp_err_t (*init)(void);

    /**
     * @brief 执行控制动作 (如 cmd="set", pos=80)
     * @param cmd 指令动作 ("set", "toggle", "stop")
     * @param param_val 整数参数值 (如开度 0~100，或开关 0/1)
     * @return esp_err_t ESP_OK 成功
     */
    esp_err_t (*apply)(const char *cmd, int32_t param_val);

    /**
     * @brief 查询当前物理状态并输出 JSON 片段
     * @param out_json 输出缓冲区 (形如 {"pos":80,"moving":false})
     * @param max_len 缓冲区最大长度
     */
    esp_err_t (*query)(char *out_json, size_t max_len);

    /**
     * @brief 周期性轮询与物理兜底逻辑
     */
    void (*poll)(void);
} link_t;

/* 外部导出的 link 实例 */
extern const link_t link_gpio;

#ifdef __cplusplus
}
#endif
