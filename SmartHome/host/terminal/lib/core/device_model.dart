/// 基础智能设备模型
abstract class SmartDevice {
  final String id;
  String name;
  String room;
  final String type;
  bool online;
  DateTime lastUpdated;

  SmartDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.type,
    this.online = true,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();
}

/// 开关类设备 (灯、插座、排风扇)
class SwitchDevice extends SmartDevice {
  bool on;
  final String subtype; // 'light', 'fan', 'socket'

  SwitchDevice({
    required super.id,
    required super.name,
    required super.room,
    this.subtype = 'light',
    this.on = false,
    super.online = true,
  }) : super(type: 'switch');
}

/// 行程类设备 (窗帘、电动卷帘、晾衣架)
class CoverDevice extends SmartDevice {
  int pos; // 0 (全关) ~ 100 (全开)
  bool moving;

  CoverDevice({
    required super.id,
    required super.name,
    required super.room,
    this.pos = 0,
    this.moving = false,
    super.online = true,
  }) : super(type: 'cover');
}

/// 整机红外空调设备 (整机状态矩阵)
class ClimateDevice extends SmartDevice {
  bool on;
  double targetTemp;
  String mode; // 'cool', 'heat', 'fan', 'dry'
  String fanSpeed; // 'auto', 'low', 'mid', 'high'

  ClimateDevice({
    required super.id,
    required super.name,
    required super.room,
    this.on = false,
    this.targetTemp = 26.0,
    this.mode = 'cool',
    this.fanSpeed = 'auto',
    super.online = true,
  }) : super(type: 'climate');
}

/// 计量加热设备 (电热水器、洗衣机状态透视)
class HeaterDevice extends SmartDevice {
  bool on;
  double powerWatts; // 实时功率
  bool heating; // 是否处于加热状态
  int remainingMinutes; // 倒计时剩余分钟

  HeaterDevice({
    required super.id,
    required super.name,
    required super.room,
    this.on = false,
    this.powerWatts = 0.0,
    this.heating = false,
    this.remainingMinutes = 0,
    super.online = true,
  }) : super(type: 'heater');
}

/// 室内环境传感器汇聚数据
class EnvironmentSensors {
  double indoorTemp; // 摄氏度
  double humidity; // 百分比
  bool smokeAlert; // 烟雾告警
  bool pirDetected; // 人体存在

  EnvironmentSensors({
    this.indoorTemp = 24.2,
    this.humidity = 53.0,
    this.smokeAlert = false,
    this.pirDetected = true,
  });
}

/// 安防模式
enum SecurityMode {
  /// 在家居家守护
  homeGuard,

  /// 离家全屋布防
  awayArmed,

  /// 紧急告警中
  alarmTriggered,
}
