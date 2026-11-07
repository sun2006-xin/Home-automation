# firmware/nodeESP — C3 节点固件（主战场）

一份固件烧 N 个节点，差异只在 `node_config.h`。

> ⚠️ 早期版本曾把这里命名为"节点/网关固件"。现已明确：**C3 不做网关，只做节点。**
> 网关角色由 broker 承担，51 面板也是节点。

## 目录约定

```
net/        net_wifi.c（STA + AP 双模）、net_ble.c、net_mqtt.c
cloud/      cloud_port.h + cloud_bemfa.c / cloud_mosquitto.c / cloud_ha.c
link/       link.h + link_gpio.c（纯节点）/ link_serial.c（对接 51）
driver/     drv_relay.c  drv_stepper.c  drv_ds18b20.c  drv_key.c  drv_led.c
node_config.h
```

## 核心抽象：link 层可插拔

```c
extern const link_t link_gpio;    /* 纯节点：C3 直接驱动电器 */
extern const link_t link_serial;  /* 中控节点：C3 通过 UART 与 51 对话 */
```

上层 net / cloud 完全不感知下层是哪种实现。**这是"两种产品形态共用一份固件"的技术关键。**

## 通信优先级（上电自动选路）

1. BLE 已连接 → 走 BLE（近场，无需路由器）
2. WiFi AP 有客户端 → 走 AP（现场调试）
3. WiFi STA + 本地 broker 可达 → 走局域网 MQTT
4. 公网 broker 可达 → 走云端 MQTT
5. 全断 → `link_gpio` 的本地按键仍可控制

## 必须实现（M7 工程化）

- [ ] 心跳 30s，3 次无响应进入 RETRY
- [ ] 指数退避重连 2s → 4s → 8s → 上限 60s
- [ ] LWT 遗嘱消息（掉线时 broker 自动发 offline）
- [ ] state 主题 retain=true（新客户端一连上就拿到最新状态）
- [ ] OTA 升级（节点装进墙盒后唯一的升级途径）
- [ ] WiFi 账号 / device_id 存 NVS，重启不丢
- [ ] BLE 与 WiFi 分时策略（BLE 连接时暂停 WiFi 重连，避免射频冲突）

## 引脚规划（C3 SuperMini，待实测定稿）

| 用途 | 备注 |
|---|---|
| 步进电机 IN1–IN4 | 4 个 GPIO，经 ULN2003 |
| 继电器 | 1 个 GPIO，注意低电平触发 |
| DS18B20 | 1 个 GPIO，4.7k 上拉 |
| 本地按键 | 1–2 个 GPIO，带内部上拉 |
| 状态 LED | 1 个 GPIO（板载） |
| UART（接 51 时） | 2 个 GPIO，交叉连接，注意 3.3V/5V 电平 |

C3 SuperMini 可用 GPIO 约 11 个，上述占用约 9 个，余量够。
