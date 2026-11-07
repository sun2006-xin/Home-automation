# firmware/ — 51 固件（Keil C51）

```
bsp/        delay.c  i2c_soft.c  uart.c  gpio.c
driver/     led.c  key.c  lcd1602.c  ds18b20.c  mq2.c  pir.c  buzzer.c
            stepper.c  relay.c
protocol/   proto_line.c          ← 阶段四才需要
app/        main.c  scene.c
```

## 建议开工顺序

1. `bsp/delay.c` → 示波器验证，这是所有时序的地基
2. `bsp/i2c_soft.c` → 与正在学的软件 I2C 写 MPU6050 同源，代码直接复用
3. `driver/lcd1602.c` → 第一次"看得见"的成果，最能提神
4. `driver/key.c` + `driver/led.c` → 阶段一闭环
5. 之后按阶段二、三推进

## 铁律

- `driver/` 与 `bsp/` 内不许出现业务阈值判断
- 主循环不许 `Delay_ms(>10)`
- 每个文件顶部注释写清：引脚、时序、已知坑
