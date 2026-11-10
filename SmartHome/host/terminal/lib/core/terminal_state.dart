import 'dart:async';
import 'package:flutter/foundation.dart';
import '../hal/hardware_key_service.dart';
import 'device_model.dart';
import 'cloud_sync_service.dart';

/// 终端全局状态与控制中枢 (TerminalState)
///
/// 架构演进：
/// 1. 两层分类控制体系：
///    - 上层：【全物品类聚合卡片】，同品类家电汇聚于同一卡片内，支持卡内左右切换与统一控制；
///    - 下层：【房间分区层叠切换】，支持“客厅 / 主卧 / 次卧(南) / 次卧(北) / 书房 / 餐厅 / 卫生间”流式切换；
/// 2. 真实温馨家居背景：集成家庭实景壁纸 + 磨砂毛玻璃护眼调光；
/// 3. 物理按键兜底：OPPO 物理音量键双键拦截闭环；
/// 4. 自定义房间与电器设置：支持多卧室、分方向房间自定义增删改；
/// 5. 工业级公网云端双向同步：全双工 WebSocket 长连接，与公网云服务器毫秒级双向感知与状态镜像。
class TerminalState extends ChangeNotifier {
  // 工业级云端全双工同步服务
  final CloudSyncService cloudSync = CloudSyncService();
  // 全屋设备清单 (覆盖客厅、主卧、次卧南/北、书房、餐厅、卫生间)
  final List<SmartDevice> allDevices = [
    // --- 客厅 ---
    SwitchDevice(id: 'L01', name: '客厅主灯', room: '客厅', on: true, subtype: 'light'),
    ClimateDevice(id: 'AC01', name: '客厅立柜空调', room: '客厅', on: true, targetTemp: 26.0, mode: 'cool'),
    CoverDevice(id: 'C01', name: '客厅主窗帘', room: '客厅', pos: 80),

    // --- 主卧 ---
    SwitchDevice(id: 'L02', name: '主卧吸顶灯', room: '主卧', on: false, subtype: 'light'),
    ClimateDevice(id: 'AC02', name: '主卧变频空调', room: '主卧', on: false, targetTemp: 25.0, mode: 'cool'),
    CoverDevice(id: 'C02', name: '主卧遮光帘', room: '主卧', pos: 0),

    // --- 次卧(南) ---
    SwitchDevice(id: 'L03', name: '南卧护眼灯', room: '次卧(南)', on: true, subtype: 'light'),
    ClimateDevice(id: 'AC03', name: '南卧冷暖空调', room: '次卧(南)', on: false, targetTemp: 26.0, mode: 'cool'),

    // --- 次卧(北) ---
    SwitchDevice(id: 'L04', name: '北卧吸顶灯', room: '次卧(北)', on: false, subtype: 'light'),

    // --- 餐厅 ---
    SwitchDevice(id: 'L05', name: '餐厅艺术吊灯', room: '餐厅', on: false, subtype: 'light'),
    SwitchDevice(id: 'F01', name: '餐厅静音风扇', room: '餐厅', on: true, subtype: 'fan'),

    // --- 书房 ---
    SwitchDevice(id: 'L06', name: '书房吸顶灯', room: '书房', on: false, subtype: 'light'),
    SwitchDevice(id: 'S01', name: '书房智能排插', room: '书房', on: true, subtype: 'socket'),

    // --- 卫生间 ---
    HeaterDevice(id: 'H01', name: '储水热水器', room: '卫生间', on: true, powerWatts: 1980.0, heating: true, remainingMinutes: 15),
    SwitchDevice(id: 'L07', name: '镜前防雾灯', room: '卫生间', on: false, subtype: 'light'),
  ];

  // 房间分类标签（支持多卧室、分朝向方向）
  final List<String> rooms = [
    '全部',
    '客厅',
    '主卧',
    '次卧(南)',
    '次卧(北)',
    '书房',
    '餐厅',
    '卫生间',
  ];
  String selectedRoom = '全部';

  // --- 品类聚合卡片当前选中设备索引 ---
  int lightIndex = 0;
  int climateIndex = 0;
  int coverIndex = 0;
  int powerIndex = 0;

  // 背景主题配置
  bool useWarmHomeBackground = true;
  double backgroundDim = 0.55;

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
    _initCloudSync();
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

  void _initCloudSync() {
    cloudSync.onStatusChanged = (_) => notifyListeners();
    cloudSync.onRemoteStateReceived = (deviceId, state) {
      _applyRemoteState(deviceId, state);
    };
    cloudSync.onSnapshotReceived = (rawDevices, rawRooms) {
      _applyRemoteSnapshot(rawDevices, rawRooms);
    };
    // 启动与云端的全双工 WebSocket 长连接
    cloudSync.connect();
  }

  void _applyRemoteState(String deviceId, Map<String, dynamic> state) {
    try {
      final dev = allDevices.firstWhere((d) => d.id == deviceId);
      if (dev is SwitchDevice && state.containsKey('on')) {
        dev.on = state['on'] == true;
      } else if (dev is ClimateDevice) {
        if (state.containsKey('on')) dev.on = state['on'] == true;
        if (state.containsKey('targetTemp')) {
          dev.targetTemp = (state['targetTemp'] as num).toDouble();
        }
        if (state.containsKey('mode')) {
          dev.mode = state['mode'].toString();
        }
      } else if (dev is CoverDevice && state.containsKey('pos')) {
        dev.pos = (state['pos'] as num).toInt();
      } else if (dev is HeaterDevice) {
        if (state.containsKey('on')) dev.on = state['on'] == true;
        if (state.containsKey('heating')) dev.heating = state['heating'] == true;
        if (state.containsKey('powerWatts')) {
          dev.powerWatts = (state['powerWatts'] as num).toDouble();
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  void _applyRemoteSnapshot(List<Map<String, dynamic>> rawDevices, List<String> rawRooms) {
    for (final raw in rawDevices) {
      final devId = raw['id'] as String?;
      final state = raw['state'] as Map<String, dynamic>?;
      if (devId != null && state != null) {
        _applyRemoteState(devId, state);
      }
    }
    if (rawRooms.isNotEmpty) {
      for (final r in rawRooms) {
        if (!rooms.contains(r)) rooms.add(r);
      }
      notifyListeners();
    }
  }

  /// 将终端当前所有电器与房间全量镜像同步到云端
  void syncAllToCloud() {
    final devList = allDevices.map((d) {
      final Map<String, dynamic> st = {};
      String type = 'switch';
      String? subtype;
      if (d is SwitchDevice) {
        type = 'switch';
        subtype = d.subtype;
        st['on'] = d.on;
      } else if (d is ClimateDevice) {
        type = 'climate';
        subtype = 'air_conditioner';
        st['on'] = d.on;
        st['targetTemp'] = d.targetTemp;
        st['mode'] = d.mode;
      } else if (d is CoverDevice) {
        type = 'cover';
        subtype = 'curtain';
        st['pos'] = d.pos;
      } else if (d is HeaterDevice) {
        type = 'heater';
        subtype = 'water_heater';
        st['on'] = d.on;
        st['heating'] = d.heating;
        st['powerWatts'] = d.powerWatts;
        st['remainingMinutes'] = d.remainingMinutes;
      }
      return {
        'id': d.id,
        'name': d.name,
        'room': d.room,
        'type': type,
        'subtype': subtype,
        'state': st,
      };
    }).toList();
    cloudSync.uploadAllToCloud(devList, rooms);
  }

  // --- 品类获取器 (Category Getters) ---

  /// 照明类设备清单
  List<SwitchDevice> get lightDevices =>
      allDevices.whereType<SwitchDevice>().where((d) => d.subtype == 'light').toList();

  /// 暖通环控类设备清单 (包含空调与风扇)
  List<SmartDevice> get climateDevices =>
      allDevices.where((d) => d is ClimateDevice || (d is SwitchDevice && d.subtype == 'fan')).toList();

  /// 遮阳门窗类设备清单
  List<CoverDevice> get coverDevices =>
      allDevices.whereType<CoverDevice>().toList();

  /// 动力与热水设备清单 (包含热水器与智能插座)
  List<SmartDevice> get powerDevices =>
      allDevices.where((d) => d is HeaterDevice || (d is SwitchDevice && d.subtype == 'socket')).toList();

  // --- 品类卡内切换方法 (Intra-category Switching) ---

  void nextLight() {
    if (lightDevices.isNotEmpty) {
      lightIndex = (lightIndex + 1) % lightDevices.length;
      notifyListeners();
    }
  }

  void prevLight() {
    if (lightDevices.isNotEmpty) {
      lightIndex = (lightIndex - 1 + lightDevices.length) % lightDevices.length;
      notifyListeners();
    }
  }

  void nextClimate() {
    if (climateDevices.isNotEmpty) {
      climateIndex = (climateIndex + 1) % climateDevices.length;
      notifyListeners();
    }
  }

  void prevClimate() {
    if (climateDevices.isNotEmpty) {
      climateIndex = (climateIndex - 1 + climateDevices.length) % climateDevices.length;
      notifyListeners();
    }
  }

  void nextCover() {
    if (coverDevices.isNotEmpty) {
      coverIndex = (coverIndex + 1) % coverDevices.length;
      notifyListeners();
    }
  }

  void prevCover() {
    if (coverDevices.isNotEmpty) {
      coverIndex = (coverIndex - 1 + coverDevices.length) % coverDevices.length;
      notifyListeners();
    }
  }

  void nextPower() {
    if (powerDevices.isNotEmpty) {
      powerIndex = (powerIndex + 1) % powerDevices.length;
      notifyListeners();
    }
  }

  void prevPower() {
    if (powerDevices.isNotEmpty) {
      powerIndex = (powerIndex - 1 + powerDevices.length) % powerDevices.length;
      notifyListeners();
    }
  }

  /// 一键控制全屋灯光
  void toggleAllLights(bool turnOn) {
    for (final l in lightDevices) {
      l.on = turnOn;
      cloudSync.sendStateUpdate(l.id, {'on': turnOn});
    }
    notifyListeners();
    syncAllToCloud();
  }

  // --- 单设备快捷方法 ---
  void toggleSwitch(SwitchDevice d) {
    d.on = !d.on;
    cloudSync.sendStateUpdate(d.id, {'on': d.on});
    notifyListeners();
  }

  void toggleClimate(ClimateDevice d) {
    d.on = !d.on;
    cloudSync.sendStateUpdate(d.id, {'on': d.on, 'targetTemp': d.targetTemp, 'mode': d.mode});
    notifyListeners();
  }

  void adjustClimateTemp(ClimateDevice d, double delta) {
    d.targetTemp = (d.targetTemp + delta).clamp(16.0, 31.0);
    cloudSync.sendStateUpdate(d.id, {'targetTemp': d.targetTemp});
    notifyListeners();
  }

  void setCoverPos(CoverDevice d, int pos) {
    d.pos = pos.clamp(0, 100);
    cloudSync.sendStateUpdate(d.id, {'pos': d.pos});
    notifyListeners();
  }

  void toggleHeater(HeaterDevice d) {
    d.on = !d.on;
    d.heating = d.on;
    d.powerWatts = d.on ? 1980.0 : 0.0;
    cloudSync.sendStateUpdate(d.id, {'on': d.on, 'heating': d.heating, 'powerWatts': d.powerWatts});
    notifyListeners();
  }

  // --- 房间层叠过滤 ---

  List<SmartDevice> get visibleDevices {
    if (selectedRoom == '全部') {
      return allDevices;
    }
    return allDevices.where((d) => d.room == selectedRoom).toList();
  }

  void selectRoom(String room) {
    if (selectedRoom != room) {
      selectedRoom = room;
      notifyListeners();
    }
  }

  // --- 房间与设备管理 ---

  void addRoom(String roomName) {
    final clean = roomName.trim();
    if (clean.isNotEmpty && !rooms.contains(clean)) {
      rooms.add(clean);
      notifyListeners();
      syncAllToCloud();
    }
  }

  void removeRoom(String roomName) {
    if (roomName == '全部' || roomName == '客厅') return; // 保留基础房间
    rooms.remove(roomName);
    // 重置该房间下的设备到客厅
    for (final d in allDevices.where((d) => d.room == roomName)) {
      d.room = '客厅';
    }
    if (selectedRoom == roomName) {
      selectedRoom = '全部';
    }
    notifyListeners();
    syncAllToCloud();
  }

  void updateDevice(String id, {String? newName, String? newRoom}) {
    final dev = allDevices.firstWhere((d) => d.id == id);
    if (newName != null && newName.trim().isNotEmpty) {
      dev.name = newName.trim();
    }
    if (newRoom != null && newRoom.trim().isNotEmpty) {
      dev.room = newRoom.trim();
    }
    notifyListeners();
    syncAllToCloud();
  }

  void toggleBackgroundTheme() {
    useWarmHomeBackground = !useWarmHomeBackground;
    notifyListeners();
  }

  // --- 物理按键处理 ---

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
        _showNotice('⚠️ 应急全切断：强电回路安全闭锁');
        break;

      case TerminalAction.muteAlarm:
        securityMode = SecurityMode.homeGuard;
        _showNotice('🔕 物理按键：告警静音');
        break;
    }
    notifyListeners();
    syncAllToCloud();
  }

  void _showNotice(String text) {
    physicalKeyNotice = text;
    notifyListeners();
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(milliseconds: 2500), () {
      physicalKeyNotice = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _noticeTimer?.cancel();
    super.dispose();
  }
}
