import 'package:flutter/services.dart';

/// 终端抽象物理动作（与具体手机硬件、按键完全解耦）
enum TerminalAction {
  /// 回家模式 (通常映射为音量加键 / MCU 独立按键 1)
  homeMode,

  /// 离家布防模式 (通常映射为音量减键 / MCU 独立按键 2)
  awayMode,

  /// 紧急全关 (长按或特定组合触发)
  emergencyAllOff,

  /// 报警消音 (电源键或消音按键)
  muteAlarm,
}

/// 硬件抽象层 (HAL) - 物理按键与系统交互服务
///
/// 工程设计：
/// 1. 采用单例模式，隔离底层操作系统与上层 UI 业务；
/// 2. 监听来自 Android Native (MainActivity) 的 MethodChannel；
/// 3. 提供回调钩子，允许任意界面层订阅物理按键事件并展示相应的触感 HUD。
class HardwareKeyService {
  static const MethodChannel _channel =
      MethodChannel('com.smarthome.terminal/hardware');

  static final HardwareKeyService _instance = HardwareKeyService._internal();
  factory HardwareKeyService() => _instance;

  void Function(TerminalAction action)? onActionTriggered;

  HardwareKeyService._internal() {
    _initChannel();
  }

  void _initChannel() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPhysicalKey') {
        final key = call.arguments as String?;
        if (key == 'VOLUME_UP') {
          _dispatch(TerminalAction.homeMode);
        } else if (key == 'VOLUME_DOWN') {
          _dispatch(TerminalAction.awayMode);
        }
      }
    });
  }

  void _dispatch(TerminalAction action) {
    // 触发轻微触感震动反馈（如果平台支持）
    HapticFeedback.mediumImpact();
    onActionTriggered?.call(action);
  }

  /// 模拟触发物理按键（用于桌面开发调试或 UI 触控兜底）
  void simulateKey(TerminalAction action) {
    _dispatch(action);
  }
}
