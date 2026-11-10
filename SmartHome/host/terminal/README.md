# 智慧家庭壁挂终端 (Terminal Kiosk) · 开发者与架构手册

> 本工程是智能家居系统的**壁挂总控大脑与交互中枢**。
> 既支持利用**闲置旧手机（Android 5.0 ~ 14）**改造成壁挂触摸中控，也为 **MCU 嵌入式小终端（ESP32-S3 + LVGL）** 预留了完全一致的数据规范。

---

## 1. 核心架构设计（三层解耦）

为了实现跨品牌手机、平板以及单片机屏幕的通用适配，本项目严禁任何业务与特定手机硬件直接耦合，整体分为三层：

```
host/terminal/
├── lib/
│   ├── hal/                       # 1. 硬件抽象层 (Hardware Abstraction Layer)
│   │   └── hardware_key_service.dart   # 物理按键拦截 (音量键/实体键映射)
│   ├── core/                      # 2. 协议与状态内核 (Domain Core)
│   │   ├── device_model.dart           # 全屋家电统一能力模型 (Switch/Cover/Climate/Heater)
│   │   └── terminal_state.dart         # 状态只认实测、状态机流转与自测试数据源
│   ├── ui/                        # 3. 自适应触感呈现层 (Tactile UI Layer)
│   │   ├── theme/terminal_theme.dart   # 触感微光深空黑主题 (防烧屏、高对比度)
│   │   ├── widgets/tactile_tiles.dart  # 拒绝AI味的实体动效卡片 (琥珀光晕、冷青微风)
│   │   ├── widgets/physical_hud_overlay.dart # 物理侧键按下时的波纹动态 HUD
│   │   └── terminal_main_screen.dart   # 2米视距响应式自适应总控主屏幕
│   └── main.dart                  # Kiosk 全屏沉浸式入口
```

---

## 2. 为什么不用抹除系统？（Kiosk 系统接管机制）

很多初学者的误区是“彻底抹掉手机系统，刷裸机系统”。在工程上这是极其危险的死胡同（BL锁变砖、闭源GPU与触控驱动丢失、无电源管理导致电池鼓包）。

本项目采用**工业级系统接管方案（Kiosk Launcher）**：
1. **底座**：保留稳定的 Android Linux 内核与驱动，负责屏幕调光、GPU 硬件渲染加速和电池温控保护；
2. **顶层**：终端程序全屏置顶（`SystemUiMode.immersiveSticky`），屏蔽系统状态栏与虚拟返回键；
3. **按键拦截**：
   - 见 `android/.../MainActivity.kt`：重写底层 `onKeyDown` 拦截 `KEYCODE_VOLUME_UP` 与 `KEYCODE_VOLUME_DOWN`；
   - 核心防御：消费事件并返回 `true`，**彻底阻止系统弹出丑陋的原生音量条**，直接转换为智能家居的“回家”与“离家”硬件指令。

---

## 3. 一键配置与调试工具使用

在 `SmartHome/host/tools/terminal_assistant.py` 中，我们为开发者提供了一个多功能命令行调试助手：

### 3.1 扫描已连接设备
```bash
python SmartHome/host/tools/terminal_assistant.py scan
```
自动读取手机屏幕分辨率、物理 DPI、安卓版本与电池健康度。

### 3.2 一键将旧手机调优为专用中控
```bash
python SmartHome/host/tools/terminal_assistant.py optimize
```
自动执行：
- 启用充电常亮模式（`stayon true`）；
- 全局强制全屏沉浸（隐藏系统下拉通知栏与三键客）；
- 设置休眠超时为 24 小时。

### 3.3 远程模拟物理按键
```bash
# 模拟按下音量+ (回家模式)
python SmartHome/host/tools/terminal_assistant.py test-keys home

# 模拟按下音量- (离家模式)
python SmartHome/host/tools/terminal_assistant.py test-keys away
```

---

## 4. 二次开发指南：如何新增一个设备卡片？

若您想增加一个新设备（例如：客厅空气净化器）：

1. **第一步：在 `lib/core/device_model.dart` 中定义或复用模型**
   ```dart
   class AirPurifierDevice extends SmartDevice {
     bool on;
     int aqi;
     AirPurifierDevice({required super.id, required super.name, required super.room, this.on = false, this.aqi = 15});
   }
   ```
2. **第二步：在 `lib/core/terminal_state.dart` 中实例化并添加控制方法**
   ```dart
   final airPurifier = AirPurifierDevice(id: 'AP01', name: '空气净化器', room: '客厅');
   void toggleAirPurifier() {
     airPurifier.on = !airPurifier.on;
     notifyListeners();
   }
   ```
3. **第三步：在 `lib/ui/widgets/tactile_tiles.dart` 中编写带微光动效的卡片组件，并在主屏栅格中引入即可。**

---

## 5. MCU 终端（ESP32-S3 + LVGL）适配规范

若您在卧室或玄关想部署几块小巧的 ESP32-S3 屏幕分机：

* **协议完全通用**：ESP32-S3 只要运行轻量级 MQTT 客户端，连接家里中枢（端口 1883）；
* **订阅全屋状态**：订阅 `sh/h01/+/state`；
* **物理按键对接**：将 ESP32-S3 的 GPIO 按键中断绑定为发布 `sh/h01/_scene/home` 与 `away` 报文；
* **与旧手机大屏无缝同步**：单片机上按一下物理键，手机大屏上的卡片与动效将在 50 毫秒内同步联动！
