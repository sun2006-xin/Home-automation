#include "net_ble.h"
#include "node_config.h"
#include "link/link.h"
#include "esp_log.h"
#include "nvs_flash.h"

#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

static const char *TAG = "NET_BLE";

/* 16位服务与特征 UUID */
#define SH_SERVICE_UUID         0xFFE0
#define SH_CHR_CMD_UUID         0xFFE1  /* 写入控制开度 (0~100) */
#define SH_CHR_STATE_UUID       0xFFE2  /* 读取与通知当前状态 */

static uint8_t s_own_addr_type;
static uint16_t s_state_val_handle;

static int gatt_svr_chr_access_cmd(uint16_t conn_handle, uint16_t attr_handle,
                                   struct ble_gatt_access_ctxt *ctxt, void *arg);

static int gatt_svr_chr_access_state(uint16_t conn_handle, uint16_t attr_handle,
                                     struct ble_gatt_access_ctxt *ctxt, void *arg);

/* GATT 服务表定义 */
static const struct ble_gatt_svc_def s_gatt_svcs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = BLE_UUID16_DECLARE(SH_SERVICE_UUID),
        .characteristics = (struct ble_gatt_chr_def[]) {
            {
                /* 特征 1: 写入控制指令 (可写) */
                .uuid = BLE_UUID16_DECLARE(SH_CHR_CMD_UUID),
                .access_cb = gatt_svr_chr_access_cmd,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
            },
            {
                /* 特征 2: 读取状态与通知 (只读 + 通知) */
                .uuid = BLE_UUID16_DECLARE(SH_CHR_STATE_UUID),
                .access_cb = gatt_svr_chr_access_state,
                .val_handle = &s_state_val_handle,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
            },
            {0}
        },
    },
    {0}
};

static int gatt_svr_chr_access_cmd(uint16_t conn_handle, uint16_t attr_handle,
                                   struct ble_gatt_access_ctxt *ctxt, void *arg) {
    if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        uint16_t len = OS_MBUF_PKTLEN(ctxt->om);
        if (len > 0) {
            uint8_t buf[32] = {0};
            uint16_t copied = 0;
            ble_hs_mbuf_to_flat(ctxt->om, buf, sizeof(buf) - 1, &copied);

            int32_t target_pos = 0;
            if (copied == 1) {
                // 单字节原生整数百分比
                target_pos = buf[0];
            } else {
                // 字符串解析 (如 "50" 或 "100")
                buf[copied] = '\0';
                target_pos = atoi((char *)buf);
            }

            ESP_LOGI(TAG, "BLE 收到开合指令: %ld%%", target_pos);
            link_gpio.apply("set", target_pos);
            return 0;
        }
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static int gatt_svr_chr_access_state(uint16_t conn_handle, uint16_t attr_handle,
                                     struct ble_gatt_access_ctxt *ctxt, void *arg) {
    if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
        char json_buf[64] = {0};
        link_gpio.query(json_buf, sizeof(json_buf));

        int rc = os_mbuf_append(ctxt->om, json_buf, strlen(json_buf));
        return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
    }
    return BLE_ATT_ERR_UNLIKELY;
}

static void start_advertising(void) {
    struct ble_gap_adv_params adv_params;
    struct ble_hs_adv_fields fields;
    int rc;

    memset(&fields, 0, sizeof(fields));
    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.tx_pwr_lvl_is_present = 1;
    fields.tx_pwr_lvl = BLE_HS_ADV_TX_PWR_LVL_AUTO;

    fields.name = (uint8_t *)NODE_BLE_DEVICE_NAME;
    fields.name_len = strlen(NODE_BLE_DEVICE_NAME);
    fields.name_is_complete = 1;

    rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "设置广播数据字段失败: %d", rc);
        return;
    }

    memset(&adv_params, 0, sizeof(adv_params));
    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(s_own_addr_type, NULL, BLE_HS_FOREVER,
                           &adv_params, NULL, NULL);
    if (rc != 0) {
        ESP_LOGE(TAG, "启动广播失败: %d", rc);
        return;
    }
    ESP_LOGI(TAG, "BLE 近场直控广播已开启: [%s]", NODE_BLE_DEVICE_NAME);
}

static void on_ble_sync(void) {
    int rc = ble_hs_util_ensure_addr(0);
    if (rc != 0) {
        ESP_LOGE(TAG, "地址校验失败: %d", rc);
        return;
    }
    rc = ble_hs_id_infer_auto(0, &s_own_addr_type);
    if (rc != 0) {
        ESP_LOGE(TAG, "确定地址类型失败: %d", rc);
        return;
    }

    start_advertising();
}

static void ble_host_task(void *param) {
    ESP_LOGI(TAG, "NimBLE 协议栈主任务开始运行");
    nimble_port_run();
    nimble_port_freertos_deinit();
}

void net_ble_notify_state(uint8_t pos) {
    if (s_state_val_handle == 0) return;
    struct os_mbuf *om = ble_hs_mbuf_from_flat(&pos, sizeof(pos));
    if (om != NULL) {
        ble_gatts_notify_custom(BLE_HS_CONN_HANDLE_NONE, s_state_val_handle, om);
    }
}

esp_err_t net_ble_init(void) {
    esp_err_t ret = nimble_port_init();
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "NimBLE 初始化失败: %d", ret);
        return ret;
    }

    ble_svc_gap_init();
    ble_svc_gatt_init();

    int rc = ble_gatts_count_cfg(s_gatt_svcs);
    if (rc != 0) return ESP_FAIL;

    rc = ble_gatts_add_svcs(s_gatt_svcs);
    if (rc != 0) return ESP_FAIL;

    ble_svc_gap_device_name_set(NODE_BLE_DEVICE_NAME);

    ble_hs_cfg.sync_cb = on_ble_sync;

    nimble_port_freertos_init(ble_host_task);
    return ESP_OK;
}
