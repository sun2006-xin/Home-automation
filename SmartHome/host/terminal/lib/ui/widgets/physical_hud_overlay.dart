import 'package:flutter/material.dart';
import '../theme/terminal_theme.dart';

/// 物理按键触发的浮动 HUD 涟漪通知条
class PhysicalHudOverlay extends StatelessWidget {
  final String? notice;

  const PhysicalHudOverlay({super.key, required this.notice});

  @override
  Widget build(BuildContext context) {
    if (notice == null) return const SizedBox.shrink();

    return Positioned(
      top: 120,
      left: 20,
      right: 20,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, val, child) {
          return Transform.translate(
            offset: Offset(0, -20 * (1.0 - val)),
            child: Opacity(opacity: val.clamp(0.0, 1.0), child: child),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B2232).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: TerminalTheme.amberWarm.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: TerminalTheme.amberWarm.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TerminalTheme.amberWarm.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.touch_app_rounded,
                  color: TerminalTheme.amberWarm,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  notice!,
                  style: const TextStyle(
                    color: TerminalTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
