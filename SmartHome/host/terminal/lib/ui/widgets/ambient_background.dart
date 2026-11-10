import 'dart:ui';
import 'package:flutter/material.dart';

/// 温馨家居微光背景渲染器 (Ambient Home Background)
///
/// 视觉设计：
/// 1. 模拟高端室内建筑微光：顶部右侧泛起温暖琥珀色壁炉/台灯光晕，左侧带有柔和深邃的夜景窗景冷光；
/// 2. 结合毛玻璃磨砂（BackdropFilter），营造深沉、温馨、具备数字实体深度的家居质感，告别冷冰冰的纯黑死寂。
class AmbientHomeBackground extends StatelessWidget {
  final Widget child;
  final bool isWarmMode;

  const AmbientHomeBackground({
    super.key,
    required this.child,
    this.isWarmMode = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isWarmMode) {
      return Container(
        color: const Color(0xFF090B0E),
        child: child,
      );
    }

    return Stack(
      children: [
        // 1. 底层温暖室内光晕模拟
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.7, -0.6), // 右上方温暖台灯/壁灯散光
                radius: 1.4,
                colors: [
                  Color(0xFF332212), // 温暖琥珀木质暖调
                  Color(0xFF1A171D), // 柔和暮光过渡
                  Color(0xFF0D0F14), // 深邃夜幕底色
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // 2. 左下方微弱冷月光环境光晕
        Positioned(
          left: -100,
          bottom: -100,
          width: 450,
          height: 450,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF003847).withValues(alpha: 0.25),
            ),
          ),
        ),

        // 3. 极细磨砂亚光层，保证前景色文字与卡片最高清晰度
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),

        // 4. 内容层
        Positioned.fill(child: child),
      ],
    );
  }
}
