import 'dart:ui';
import 'package:flutter/material.dart';

/// 温馨家居实景微光背景渲染器 (Ambient Home Wallpaper & Lighting)
///
/// 视觉设计：
/// 1. 真实温馨家庭场景：加载 Japandi / 现代暖木风格客厅壁纸（沙发、地毯、暖光灯带、绿植、木地板）；
/// 2. 护眼高对比度磨砂蒙层：覆盖渐变半透明暖黑蒙层与柔和高斯模糊，让家的温馨图景透光溢彩，
///    同时确保前台仪表盘文字、数字、卡片图标具备 100% 锐利高对比度，绝对不反光、不刺眼、无视疲劳。
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
        // 1. 底层：温馨家庭实景照片
        Positioned.fill(
          child: Image.asset(
            'assets/images/cozy_home_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (context, error, stackTrace) {
              // 容错兜底：若文件不可读，降级为暖色室内漫反射渐变
              return Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, -0.5),
                    radius: 1.3,
                    colors: [
                      Color(0xFF382515),
                      Color(0xFF1F1A20),
                      Color(0xFF0E1015),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
        ),

        // 2. 中层：暖调半透明遮罩与毛玻璃漫反射（与原木家具壁纸自然融为一体）
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x751A120B), // 顶部暖栗色半透
                    Color(0x9E140C07), // 底部温暖深褐过渡
                  ],
                ),
              ),
            ),
          ),
        ),

        // 3. 微弱暖光光晕叠加，增强自然温馨感
        Positioned(
          top: -60,
          right: 80,
          width: 320,
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFB347).withValues(alpha: 0.08),
            ),
          ),
        ),

        // 4. 内容层
        Positioned.fill(child: child),
      ],
    );
  }
}
