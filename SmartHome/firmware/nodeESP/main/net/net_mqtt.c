/**
 * @file net_mqtt.c
 * @brief ESP32-C3 本地总线 MQTT 协议栈实现 (自发现/LWT/状态发布/指令解析)
 */

#include "net_mqtt.h"
#include "net_wifi.h"
#include "node_config.h"
#include "link/link.h"
#include "driver/drv_stepper.h"
#include "driver/drv_led.h"
#include "mqtt_client.h"
#include "esp_log.h"
#include "cJSON.h"
#include <string.h>
#include <stdio.h>

static const char *TAG = "NET_MQTT";

static esp_mqtt_client_handle_t s_client = NULL;
static bool s_is_connected = false;

/* 预生成主题缓存 */
static char s_topic_online[64];
static char s_topic_state[64];
static char s_topic_cmd[64];
static char s_topic_broadcast[64];
static char s_topic_discovery[64];

static void init_topics(void) {
    snprintf(s_topic_online, sizeof(s_topic_online), "sh/%s/%s/online", HOME_ID, NODE_DEVICE_ID);
    snprintf(s_topic_state, sizeof(s_topic_state), "sh/%s/%s/state", HOME_ID, NODE_DEVICE_ID);
    snprintf(s_topic_cmd, sizeof(s_topic_cmd), "sh/%s/%s/cmd", HOME_ID, NODE_DEVICE_ID);
    snprintf(s_topic_broadcast, sizeof(s_topic_broadcast), "sh/%s/broadcast", HOME_ID);
    snprintf(s_topic_discovery, sizeof(s_topic_discovery), "sh/%s/_discovery", HOME_ID);
}

esp_err_t net_mqtt_publish_discovery(void) {
    if (!s_is_connected || s_client == NULL) return ESP_FAIL;

    char ip_str[16] = {0};
    net_wifi_get_ip_str(ip_str, sizeof(ip_str));

    cJSON *root = cJSON_CreateObject();
    if (root == NULL) return ESP_ERR_NO_MEM;

    cJSON_AddNumberToObject(root, "v", 1);
    cJSON_AddStringToObject(root, "id", NODE_DEVICE_ID);
    cJSON_AddStringToObject(root, "name", NODE_DEVICE_NAME);
    cJSON_AddStringToObject(root, "room", NODE_DEVICE_ROOM);
    cJSON_AddStringToObject(root, "type", "cover");
    
    cJSON *caps = cJSON_CreateArray();
    cJSON_AddItemToArray(caps, cJSON_CreateString("cover"));
    cJSON_AddItemToObject(root, "cap", caps);

    cJSON *cmds = cJSON_CreateArray();
    cJSON_AddItemToArray(cmds, cJSON_CreateString("set"));
    cJSON_AddItemToArray(cmds, cJSON_CreateString("stop"));
    cJSON_AddItemToObject(root, "cmds", cmds);

    cJSON_AddStringToObject(root, "fw", NODE_FW_VERSION);
    cJSON_AddStringToObject(root, "ip", ip_str);

    char *json_str = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);

    if (json_str == NULL) return ESP_ERR_NO_MEM;

    int msg_id = esp_mqtt_client_publish(s_client, s_topic_discovery, json_str, 0, 1, 1);
    ESP_LOGI(TAG, "已发布设备自发现声明包至 [%s], msg_id=%d", s_topic_discovery, msg_id);

    free(json_str);
    return ESP_OK;
}

esp_err_t net_mqtt_publish_state(uint8_t pos) {
    if (!s_is_connected || s_client == NULL) return ESP_FAIL;

    char payload[128];
    snprintf(payload, sizeof(payload),
             "{\"v\":1,\"d\":\"%s\",\"st\":{\"pos\":%u,\"moving\":0}}",
             NODE_DEVICE_ID, pos);

    int msg_id = esp_mqtt_client_publish(s_client, s_topic_state, payload, 0, 1, 1);
    ESP_LOGI(TAG, "已发布状态快照 -> 主题: %s, 内容: %s (msg_id=%d)", s_topic_state, payload, msg_id);
    return ESP_OK;
}

static void handle_incoming_cmd(const char *data, int data_len) {
    char buf[256];
    if (data_len >= sizeof(buf)) {
        ESP_LOGE(TAG, "收到过长指令载荷 (%d 字节)，丢弃", data_len);
        return;
    }
    memcpy(buf, data, data_len);
    buf[data_len] = '\0';

    ESP_LOGI(TAG, "收到指令载荷: %s", buf);

    /* 尝试 JSON 反序列化 */
    cJSON *root = cJSON_Parse(buf);
    if (root != NULL) {
        cJSON *cmd_item = cJSON_GetObjectItem(root, "cmd");
        cJSON *args_item = cJSON_GetObjectItem(root, "args");
        
        if (cmd_item != NULL && cJSON_IsString(cmd_item)) {
            const char *cmd = cmd_item->valuestring;
            int32_t param_val = 0;

            if (args_item != NULL && cJSON_IsObject(args_item)) {
                cJSON *pos_item = cJSON_GetObjectItem(args_item, "pos");
                if (pos_item != NULL && cJSON_IsNumber(pos_item)) {
                    param_val = pos_item->valueint;
                }
            }

            link_gpio.apply(cmd, param_val);
        } else {
            /* 兼容简易键值 {"pos": 50} */
            cJSON *pos_item = cJSON_GetObjectItem(root, "pos");
            if (pos_item != NULL && cJSON_IsNumber(pos_item)) {
                link_gpio.apply("set", pos_item->valueint);
            }
        }
        cJSON_Delete(root);
    } else {
        /* 纯文本/数字兼容 (如直接下发 "50" 或 "stop") */
        if (strcmp(buf, "stop") == 0) {
            link_gpio.apply("stop", 0);
        } else {
            link_gpio.apply("set", atoi(buf));
        }
    }
}

static void mqtt_event_handler(void *handler_args, esp_event_base_t base,
                               int32_t event_id, void *event_data) {
    esp_mqtt_event_handle_t event = (esp_mqtt_event_handle_t)event_data;

    switch (event->event_id) {
        case MQTT_EVENT_CONNECTED:
            ESP_LOGI(TAG, "成功连接到本地 MQTT Broker: %s", CONFIG_MQTT_BROKER_URI);
            s_is_connected = true;

            /* 1. 发布在线遗嘱确认 */
            esp_mqtt_client_publish(s_client, s_topic_online, "1", 1, 1, 1);

            /* 2. 订阅专用控制指令主题 */
            esp_mqtt_client_subscribe(s_client, s_topic_cmd, 1);
            ESP_LOGI(TAG, "已订阅控制主题: %s", s_topic_cmd);

            /* 3. 订阅全屋广播主题 */
            esp_mqtt_client_subscribe(s_client, s_topic_broadcast, 1);

            /* 4. 上报自发现声明 */
            net_mqtt_publish_discovery();

            /* 5. 上报当前状态快照 */
            net_mqtt_publish_state(drv_stepper_get_pos());
            break;

        case MQTT_EVENT_DISCONNECTED:
            ESP_LOGW(TAG, "与本地 MQTT Broker 断开连接，自动重连中...");
            s_is_connected = false;
            break;

        case MQTT_EVENT_DATA:
            if (event->topic_len > 0) {
                if (strncmp(event->topic, s_topic_cmd, event->topic_len) == 0 ||
                    strncmp(event->topic, s_topic_broadcast, event->topic_len) == 0) {
                    handle_incoming_cmd(event->data, event->data_len);
                }
            }
            break;

        case MQTT_EVENT_ERROR:
            ESP_LOGE(TAG, "MQTT 传输层错误发生");
            break;

        default:
            break;
    }
}

esp_err_t net_mqtt_init(void) {
    init_topics();

    esp_mqtt_client_config_t mqtt_cfg = {
        .broker.address.uri = CONFIG_MQTT_BROKER_URI,
        .session.last_will = {
            .topic = s_topic_online,
            .msg = "0",
            .msg_len = 1,
            .qos = 1,
            .retain = 1,
        },
        .credentials.client_id = "SH_" NODE_DEVICE_ID,
    };

    s_client = esp_mqtt_client_init(&mqtt_cfg);
    if (s_client == NULL) {
        ESP_LOGE(TAG, "esp_mqtt_client_init 失败");
        return ESP_FAIL;
    }

    esp_mqtt_client_register_event(s_client, ESP_EVENT_ANY_ID, mqtt_event_handler, s_client);

    esp_err_t ret = esp_mqtt_client_start(s_client);
    if (ret != ESP_OK) {
        ESP_LOGE(TAG, "esp_mqtt_client_start 失败: %d", ret);
        return ret;
    }

    ESP_LOGI(TAG, "MQTT 客户端模块初始化完成，正在连接 Broker...");
    return ESP_OK;
}

bool net_mqtt_is_connected(void) {
    return s_is_connected;
}
