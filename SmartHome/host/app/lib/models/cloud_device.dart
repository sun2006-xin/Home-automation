import 'package:flutter/material.dart';

class CloudDevice {
  final String id;
  final String name;
  final String room;
  final String type; // switch | climate | cover | heater
  final String? subtype; // light | fan | socket | air_conditioner | curtain | water_heater
  final Map<String, dynamic> state;
  final double updatedAt;

  const CloudDevice({
    required this.id,
    required this.name,
    required this.room,
    required this.type,
    this.subtype,
    required this.state,
    required this.updatedAt,
  });

  factory CloudDevice.fromJson(Map<String, dynamic> json) {
    return CloudDevice(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      room: (json['room'] ?? '默认房间').toString(),
      type: (json['type'] ?? 'switch').toString(),
      subtype: json['subtype']?.toString(),
      state: Map<String, dynamic>.from(json['state'] as Map? ?? {}),
      updatedAt: (json['updated_at'] is num)
          ? (json['updated_at'] as num).toDouble()
          : DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
  }

  CloudDevice copyWith({
    Map<String, dynamic>? state,
    double? updatedAt,
  }) {
    return CloudDevice(
      id: id,
      name: name,
      room: room,
      type: type,
      subtype: subtype,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLight => type == 'switch' && subtype == 'light';
  bool get isFan => type == 'switch' && subtype == 'fan';
  bool get isSocket => type == 'switch' && subtype == 'socket';
  bool get isClimate => type == 'climate';
  bool get isCover => type == 'cover';
  bool get isHeater => type == 'heater';

  bool get isActive {
    if (isCover) return coverPos > 0;
    return state['on'] == true;
  }

  double get targetTemp {
    final val = state['targetTemp'];
    return val is num ? val.toDouble() : 26.0;
  }

  String get climateMode => (state['mode'] ?? 'cool').toString();

  int get coverPos {
    final val = state['pos'];
    return val is num ? val.toInt().clamp(0, 100) : 0;
  }

  double get powerWatts {
    final val = state['powerWatts'];
    if (val is num) return val.toDouble();
    if (!isActive) return 0;
    if (isLight) return 16;
    if (isFan) return 38;
    if (isSocket) return 65;
    if (isClimate) return 820;
    if (isHeater) return 1980;
    return 0;
  }

  bool get isHeating => state['heating'] == true;

  int get remainingMinutes {
    final val = state['remainingMinutes'];
    return val is num ? val.toInt() : 15;
  }

  String get statusLabel {
    if (isClimate) {
      if (!isActive) return '已关机';
      final modeName = switch (climateMode) {
        'heat' => '制热',
        'fan' => '送风',
        _ => '制冷',
      };
      return '${targetTemp.toStringAsFixed(1)}°C · $modeName';
    }
    if (isCover) {
      if (coverPos == 0) return '已关闭';
      if (coverPos == 100) return '全开启';
      return '开合 $coverPos%';
    }
    if (isHeater) {
      if (!isActive) return '已断电';
      return isHeating ? '加热中 · ${powerWatts.toInt()}W' : '恒温保温';
    }
    return isActive ? '已开启' : '已关闭';
  }

  Color get accentColor {
    if (isClimate) return const Color(0xFF0071E3);
    if (isCover) return const Color(0xFF6366F1);
    if (isHeater || isSocket) return const Color(0xFFF97316);
    if (isFan) return const Color(0xFF0EA5E9);
    return const Color(0xFFF59E0B);
  }

  IconData get iconData {
    if (isClimate) return Icons.ac_unit_rounded;
    if (isCover) return Icons.curtains_rounded;
    if (isHeater) return Icons.water_drop_rounded;
    if (isFan) return Icons.wind_power_rounded;
    if (isSocket) return Icons.power_rounded;
    return Icons.lightbulb_rounded;
  }
}

class ScenePreset {
  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
  final Color color;

  const ScenePreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

const kMiScenes = <ScenePreset>[
  ScenePreset(
    id: 'home',
    name: '回家模式',
    subtitle: '亮起客厅灯光、拉开窗帘并开启客厅空调',
    icon: Icons.home_rounded,
    color: Color(0xFFF59E0B),
  ),
  ScenePreset(
    id: 'away',
    name: '离家警戒',
    subtitle: '关闭全屋照明与空调，拉合所有遮阳窗帘',
    icon: Icons.shield_rounded,
    color: Color(0xFF0071E3),
  ),
  ScenePreset(
    id: 'sleep',
    name: '舒适睡眠',
    subtitle: '关闭客厅电器与窗帘，保持主卧 26°C 静音制冷',
    icon: Icons.nights_stay_rounded,
    color: Color(0xFF6366F1),
  ),
  ScenePreset(
    id: 'all_lights_on',
    name: '全屋亮灯',
    subtitle: '一键开启所有房间照明回路',
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFFF59E0B),
  ),
  ScenePreset(
    id: 'all_lights_off',
    name: '全屋关灯',
    subtitle: '一键关闭全屋全部照明灯具',
    icon: Icons.lightbulb_outline_rounded,
    color: Color(0xFF64748B),
  ),
  ScenePreset(
    id: 'all_off',
    name: '一键全关',
    subtitle: '切断照明、空调与热水器大功率负载',
    icon: Icons.power_settings_new_rounded,
    color: Color(0xFFEF4444),
  ),
];
