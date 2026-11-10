import 'package:flutter/material.dart';

/// 壁挂终端专属质感主题 (Tactile Dark Glassmorphism)
///
/// 视觉原则：
/// 1. 拒绝千篇一律的白底灰字与刺眼渐变；
/// 2. 采用深空黑底色 (#090B0E) 保护旧手机 OLED/LCD 寿命与能耗；
/// 3. 设备状态激活时采用物理级微光晕染（灯光为暖琥珀、空调为冷青色、安防为电光绿）。
class TerminalTheme {
  // 背景色系
  static const Color background = Color(0xFF090B0E);
  static const Color surfaceCard = Color(0xFF131822);
  static const Color surfaceCardActive = Color(0xFF18202D);
  static const Color borderSubtle = Color(0xFF222B3A);

  // 状态微光色系
  static const Color amberWarm = Color(0xFFFFB300); // 暖琥珀：照明
  static const Color cyanCool = Color(0xFF00E5FF);  // 冷青色：制冷/空气
  static const Color tealSafe = Color(0xFF00E676);  // 电光绿：在线/安全
  static const Color crimsonAlert = Color(0xFFFF334B); // 信号红：紧急/告警
  static const Color purpleMode = Color(0xFF7C4DFF);   // 场景模式

  // 文字分级
  static const Color textPrimary = Color(0xFFF0F4F8);
  static const Color textSecondary = Color(0xFF8E9BAE);
  static const Color textMuted = Color(0xFF5A6677);

  // 投影与光晕效果
  static List<BoxShadow> amberGlow = [
    BoxShadow(
      color: amberWarm.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static List<BoxShadow> cyanGlow = [
    BoxShadow(
      color: cyanCool.withValues(alpha: 0.25),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'sans-serif',
      cardColor: surfaceCard,
    );
  }
}
