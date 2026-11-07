# firmware/node51 — 51 中控面板固件（仅 M5 使用）

> ⚠️ 定位修正：这块 51 **不是主控，不是网关**。
> 它只是一块带屏幕和按键的**面板节点**，通过一块 C3 当网卡接入总线。
> 纯 C3 形态（形态 A/B）完全不需要本目录的任何代码。

## 职责边界

| 做 | 不做 |
|---|---|
| LCD1602 显示全屋设备状态 | ❌ 不连 WiFi、不懂 MQTT |
| 实体按键 K3/K4 发起控制 | ❌ 不转发其他节点的数据 |
| 本地联动规则（断网时生效） | ❌ 不存全屋状态表（RAM 不够） |
| 蜂鸣器报警 | ❌ 不解析 JSON |

## 目录约定

```
bsp/        bsp_delay.c  bsp_uart.c  bsp_i2c_soft.c  bsp_gpio.c
driver/     drv_lcd1602.c  drv_key.c  drv_buzzer.c  drv_ds18b20.c
protocol/   proto_line.c  proto_line.h      ← 与 C3 的行协议
app/        app_panel.c（面板 UI）  app_scene.c（本地联动）
```

## 接口

只与一块 C3 通过 UART 通信：

```
51 → C3：   P00;CMD=L01;ON\r\n        用户在面板上按了"开灯"
C3 → 51：   P00;DISP=L01=1;C01=50\r\n  全屋状态快照，刷新 LCD
            S01;T=25.3\r\n             传感器值
```

## 复用的预科代码

M5 之前用原方案四阶段练手的代码，可以直接搬进本目录：

| 预科 | 搬到这里 |
|---|---|
| 预一（I2C LCD + 按键） | `driver/drv_lcd1602.c` `driver/drv_key.c` |
| 预二（DS18B20 + 蜂鸣器） | `driver/drv_ds18b20.c` `driver/drv_buzzer.c` |
| 预四（UART 收发） | `bsp/bsp_uart.c` + `protocol/proto_line.c` |

## 编码约定

- 主循环**禁止** `Delay_ms(>10)`，全部改定时器计数非阻塞
- 全局变量一律 `static`，跨文件 `extern`
- 每个驱动文件顶部写清：引脚、时序、已知坑
