import 'dart:async';
import 'package:flutter/foundation.dart';
import '../hal/hardware_key_service.dart';
import 'device_model.dart';

/// 终端全局状态与控制中枢 (TerminalState)
///
/// 核心升级：
/// 1. 房间分组与层叠切换：支持“全部 / 客厅 / 餐厅 / 主卧 / 厨房 / 卫生间”流式切换；
/// 2. 自定义配置能力：支持自主修改任意电器的【显示名称】、【硬件ID】与【归属房间】；
/// 3. 温馨家居背景主题：支持深空玻璃与温暖家居环境光动态切换；
/// 4. 物理按键硬件级兜底拦截与实测闭环。
class TerminalState extends ChangeNotifier {
  // 全屋设备清单 (支持动态增删查改)
  final List<SmartDevice> allDevices = [
    // --- 客厅 ---
    SwitchDevice(id: 'L01', name: '客厅主灯', room: '客厅', on: true, subtype: 'light'),
    ClimateDevice(id: 'AC01', name: '客厅立柜空调', room: '客厅', on: true, targetTemp: 26.0, mode: 'cool'),
    CoverDevice(id: 'C01', name: '客厅主窗帘', room: '客厅', pos: 75),
    
    // --- 餐厅 ---
    SwitchDevice(id: 'L02', name: '餐厅吊灯', room: '餐厅', on: false, subtype: 'light'),
    SwitchDevice(id: 'F01', name: '复古静音风扇', room: '餐厅', on: true, subtype: 'fan'),

    // --- 主卧 ---
    SwitchDevice(id: 'L03', name: '主卧吸顶灯', room: '主卧', on: false, subtype: 'light'),
    CoverDevice(id: 'C02', name: '主卧纱帘', room: '主卧', pos: 30),

    // --- 厨房与卫生间 ---
    HeaterDevice(id: 'H01', name: '储水热水器', room: '卫生间', on: true, powerWatts: 1980.0, heating: true, remainingMinutes: 15),
  ];

  // 房间分类标签
  final List<String> rooms = ['全部', '客厅', '餐厅', '主卧', '卫生间'];
  String selectedRoom = '全部';

  // 背景主题：true=温馨家居环境光, false=极简深空黑
  bool useWarmHomeBackground = true;

  // 传感器与安防模式
  final EnvironmentSensors sensors = EnvironmentSensors();
  SecurityMode securityMode = SecurityMode.homeGuard;

  // 物理按键瞬态 HUD 提示
  String? physicalKeyNotice;
  Timer? _noticeTimer;

  // 实时时钟
  DateTime now = DateTime.now();
  Timer? _clockTimer;

  TerminalState() {
    _initClock();
    _bindHardwareKeys();
  }

  void _initClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      notifyListeners();
    });
  }

  void _bindHardwareKeys() {
    HardwareKeyService().onActionTriggered = (action) {
      handlePhysicalAction(action);
    };
  }

  /// 获取当前筛选的设备列表
  List<SmartDevice> get visibleDevices {
    if (selectedRoom == '全部') {
      return allDevices;
    }
    return allDevices.where((d) => d.room == selectedRoom).toList();
  }

  /// 切换房间分组
  void selectRoom(String room) {
    if (selectedRoom != room) {
      selectedRoom = room;
      notifyListeners();
    }
  }

  /// 切换温馨背景模式
  void toggleBackgroundTheme() {
    useWarmHomeBackground = !useWarmHomeBackground;
    notifyListeners();
  }

  /// 自定义修改设备属性 (名称与房间)
  void updateDevice(String id, {String? newName, String? newRoom}) {
    final dev = allDevices.firstWhere((d) => d.id == id);
    if (newName != null && newName.trim().isNotEmpty) {
      dev.name = newName.trim();
    }
    if (newRoom != null && newRoom.trim().isNotEmpty) {
      dev.room = newRoom.trim();
    }
    notifyListeners();
  }

  /// 处理硬件物理按键动作
  void handlePhysicalAction(TerminalAction action) {
    switch (action) {
      case TerminalAction.homeMode:
        securityMode = SecurityMode.homeGuard;
        for (final d in allDevices) {
          if (d.id == 'L01' && d is SwitchDevice) d.on = true;
          if (d.id == 'C01' && d is CoverDevice) d.pos = 80;
          if (d.id == 'AC01' && d is ClimateDevice) {
            d.on = true;
            d.targetTemp = 26.0;
          }
          if (d.id == 'H01' && d is HeaterDevice) {
            d.on = true;
            d.heating = true;
            d.powerWatts = 2000.0;
          }
        }
        _showNotice('🏠 物理按键触发 · 回家模式已执行');
        break;

      case TerminalAction.awayMode:
        securityMode = SecurityMode.awayArmed;
        for (final d in allDevices) {
          if (d is SwitchDevice) d.on = false;
          if (d is CoverDevice) d.pos = 0;
          if (d is ClimateDevice) d.on = false;
          if (d is HeaterDevice) {
            d.on = false;
            d.heating = false;
            d.powerWatts = 0.0;
          }
        }
        _showNotice('🌙 物理按键触发 · 全屋离家断电布防');
        break;

      case TerminalAction.emergencyAllOff:
        for (final d in allDevices) {
          if (d is SwitchDevice) d.on = false;
          if (d is ClimateDevice) d.on = false;
          if (d is HeaterDevice) d.on = false;
        }
        _showNotice('⚡ 物理长按 · 紧急全屋切断');
        break;

      case TerminalAction.muteAlarm:
        sensors.smokeAlert = false;
        _showNotice('🔕 物理按键 · 告警已确认静音');
        break;
    }
    notifyListeners();
  }

  void _showNotice(String msg) {
    _noticeTimer?.cancel();
    physicalKeyNotice = msg;
    notifyListeners();

    _noticeTimer = Timer(const Duration(seconds: 3), () {
      physicalKeyNotice = null;
      notifyListeners();
    });
  }

  // --- 设备通用控制交互 ---

  void toggleSwitch(SwitchDevice dev) {
    dev.on = !dev.on;
    notifyListeners();
  }

  void toggleClimate(ClimateDevice dev) {
    dev.on = !dev.on;
    notifyListeners();
  }

  void adjustClimateTemp(ClimateDevice dev, double delta) {
    dev.targetTemp = (dev.targetTemp + delta).clamp(16.0, 30.0);
    notifyListeners();
  }

  void setCoverPos(CoverDevice dev, int newPos) {
    dev.pos = newPos.clamp(0, 100);
    dev.moving = true;
    notifyListeners();

    Timer(const Duration(milliseconds: 700), () {
      dev.moving = false;
      notifyListeners();
    });
  }

  void toggleHeater(HeaterDevice dev) {
    dev.on = !dev.on;
    if (dev.on) {
      dev.heating = true;
      dev.powerWatts = 2000.0;
      dev.remainingMinutes = 20;
    } else {
      dev.heating = false;
      dev.powerWatts = 0.0;
      dev.remainingMinutes = 0;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}
