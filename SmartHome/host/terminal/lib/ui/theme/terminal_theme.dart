import 'package:flutter/material.dart';

/// 壁挂终端专属质感主题 (Tactile Ambient Glassmorphism)
///
/// 视觉设计：
/// 1. 【温馨家庭模式 (Warm Home Mode)】：
///    - 采用暖焦糖琥珀半透玻璃 (#66241A12) 与香槟暖金边框，与原木家具、天花暖光、布艺沙发浑然一体；
///    - 按钮、卡片容器告别冷黑与深灰，使用温润的暖栗色与焦糖金，文字采用象牙暖白；
/// 2. 【极简深空模式 (Obsidian Mode)】：
///    - 经典的深空黑 (#090B0E) 与冷靛蓝毛玻璃，适合夜间极客纯暗场景。
class TerminalTheme {
  // ================= 1. 温馨家居暖木玻璃色系 (Warm Home Mode) =================
  static const Color warmCardBg = Color(0x66241A12);         // 半透暖焦糖木质玻璃底
  static const Color warmCardActive = Color(0x8A3A291C);     // 激活时暖光温润泛光
  static const Color warmCardBorder = Color(0x40E0A96D);     // 香槟暖金超细微光边框
  static const Color warmButtonBg = Color(0x4D36271D);       // 暖木色按钮底
  static const Color warmButtonActive = Color(0x8FD48B47);   // 暖焦糖激活按钮
  static const Color warmButtonBorder = Color(0x55E0A96D);   // 暖金按钮边框
  static const Color warmPillActive = Color(0xFFC87D32);     // 房间激活暖焦糖胶囊
  static const Color warmTopBarBg = Color(0x7520160F);       // 顶部暖褐磨砂底
  static const Color warmTextPrimary = Color(0xFFFFF8F0);    // 象牙暖白主文字
  static const Color warmTextSecondary = Color(0xFFDCC8B6);  // 亚麻米褐次级文字
  static const Color warmTextMuted = Color(0xFFA6907D);      // 柔和暖灰辅助文字

  // ================= 2. 极简深空黑底色系 (Obsidian Mode) =================
  static const Color background = Color(0xFF090B0E);
  static const Color surfaceCard = Color(0xFF131822);
  static const Color surfaceCardActive = Color(0xFF18202D);
  static const Color borderSubtle = Color(0xFF222B3A);

  // 状态微光色系
  static const Color amberWarm = Color(0xFFFFB300); // 暖琥珀：照明
  static const Color amberPrimary = amberWarm;
  static const Color cyanCool = Color(0xFF00E5FF);  // 冷青色：制冷/空气
  static const Color cyanActive = cyanCool;
  static const Color tealSafe = Color(0xFF00E676);  // 电光绿：在线/安全
  static const Color crimsonAlert = Color(0xFFFF334B); // 信号红：紧急/告警
  static const Color purpleMode = Color(0xFF7C4DFF);   // 场景模式
  static const Color glassBorder = Color(0x2EFFFFFF); // 毛玻璃微边框

  // 文字分级 (通用默认)
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
