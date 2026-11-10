import 'package:flutter/material.dart';
import '../theme/terminal_theme.dart';
import '../../core/device_model.dart';
import '../../core/terminal_state.dart';

/// 触感卡片分发器 (动态选择不同品类的交互卡片，根据主题自适应暖木/深空质感)
Widget buildDeviceTile(SmartDevice device, TerminalState state) {
  final isWarm = state.useWarmHomeBackground;

  if (device is SwitchDevice) {
    return TactileSwitchTile(
      device: device,
      isWarm: isWarm,
      onToggle: () => state.toggleSwitch(device),
    );
  } else if (device is ClimateDevice) {
    return TactileClimateTile(
      device: device,
      isWarm: isWarm,
      onToggle: () => state.toggleClimate(device),
      onTempAdjust: (delta) => state.adjustClimateTemp(device, delta),
    );
  } else if (device is CoverDevice) {
    return TactileCoverTile(
      device: device,
      isWarm: isWarm,
      onSetPos: (pos) => state.setCoverPos(device, pos),
    );
  } else if (device is HeaterDevice) {
    return TactileHeaterTile(
      device: device,
      isWarm: isWarm,
      onToggle: () => state.toggleHeater(device),
    );
  }
  return const SizedBox.shrink();
}

/// 1. 通用开关卡片 (灯具、风扇、插座 - 暖木/深空自适应)
class TactileSwitchTile extends StatefulWidget {
  final SwitchDevice device;
  final bool isWarm;
  final VoidCallback onToggle;

  const TactileSwitchTile({
    super.key,
    required this.device,
    this.isWarm = false,
    required this.onToggle,
  });

  @override
  State<TactileSwitchTile> createState() => _TactileSwitchTileState();
}

class _TactileSwitchTileState extends State<TactileSwitchTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.device.on;
    final isFan = widget.device.subtype == 'fan';
    final isWarm = widget.isWarm;

    final Color accentColor = isFan ? TerminalTheme.cyanCool : TerminalTheme.amberWarm;
    final IconData iconData = isFan ? Icons.mode_fan_off_rounded : Icons.lightbulb_rounded;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onToggle();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active
                ? (isWarm ? TerminalTheme.warmCardActive : TerminalTheme.surfaceCardActive)
                : (isWarm ? TerminalTheme.warmCardBg : TerminalTheme.surfaceCard),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? accentColor.withValues(alpha: 0.6)
                  : (isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.borderSubtle),
              width: active ? 1.5 : 1.0,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: active
                          ? accentColor.withValues(alpha: 0.2)
                          : (isWarm ? const Color(0x33443325) : Colors.white.withValues(alpha: 0.05)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      iconData,
                      color: active ? accentColor : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                      size: 20,
                    ),
                  ),
                  Text(
                    active ? '已开启' : '已关闭',
                    style: TextStyle(
                      color: active ? accentColor : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    active ? '回路通电中' : '回路切断',
                    style: TextStyle(
                      color: isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2. 客厅空调卡片
class TactileClimateTile extends StatefulWidget {
  final ClimateDevice device;
  final bool isWarm;
  final VoidCallback onToggle;
  final Function(double delta) onTempAdjust;

  const TactileClimateTile({
    super.key,
    required this.device,
    this.isWarm = false,
    required this.onToggle,
    required this.onTempAdjust,
  });

  @override
  State<TactileClimateTile> createState() => _TactileClimateTileState();
}

class _TactileClimateTileState extends State<TactileClimateTile> {
  @override
  Widget build(BuildContext context) {
    final active = widget.device.on;
    final isWarm = widget.isWarm;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? (isWarm ? TerminalTheme.warmCardActive : TerminalTheme.surfaceCardActive)
            : (isWarm ? TerminalTheme.warmCardBg : TerminalTheme.surfaceCard),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? TerminalTheme.cyanCool.withValues(alpha: 0.6)
              : (isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.borderSubtle),
          width: active ? 1.5 : 1.0,
        ),
        boxShadow: active ? TerminalTheme.cyanGlow : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: active
                        ? TerminalTheme.cyanCool.withValues(alpha: 0.2)
                        : (isWarm ? const Color(0x33443325) : Colors.white.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.ac_unit_rounded,
                    color: active
                        ? TerminalTheme.cyanCool
                        : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                    size: 18,
                  ),
                ),
              ),
              if (active)
                Row(
                  children: [
                    _circleButton(Icons.remove, () => widget.onTempAdjust(-0.5)),
                    const SizedBox(width: 4),
                    _circleButton(Icons.add, () => widget.onTempAdjust(0.5)),
                  ],
                )
              else
                Text(
                  '已待机',
                  style: TextStyle(
                    color: isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    active ? '${widget.device.targetTemp.toStringAsFixed(1)}°' : '--',
                    style: TextStyle(
                      color: active
                          ? TerminalTheme.cyanCool
                          : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    active ? '制冷' : '待机',
                    style: TextStyle(
                      color: active
                          ? (isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary)
                          : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                widget.device.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    final isWarm = widget.isWarm;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isWarm ? TerminalTheme.warmButtonBg : TerminalTheme.borderSubtle,
          border: Border.all(
            color: isWarm ? TerminalTheme.warmButtonBorder : Colors.transparent,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 13,
          color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
        ),
      ),
    );
  }
}

/// 3. 客厅窗帘卡片
class TactileCoverTile extends StatelessWidget {
  final CoverDevice device;
  final bool isWarm;
  final Function(int pos) onSetPos;

  const TactileCoverTile({
    super.key,
    required this.device,
    this.isWarm = false,
    required this.onSetPos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarm ? TerminalTheme.warmCardBg : TerminalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFB388FF).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.curtains_rounded,
                  color: Color(0xFFB388FF),
                  size: 18,
                ),
              ),
              Text(
                device.moving ? '运行中...' : '${device.pos}%',
                style: TextStyle(
                  color: device.moving
                      ? TerminalTheme.amberWarm
                      : (isWarm ? const Color(0xFFD1B3FF) : TerminalTheme.textSecondary),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _pillAction('全开', 100),
                  const SizedBox(width: 4),
                  _pillAction('半开', 50),
                  const SizedBox(width: 4),
                  _pillAction('全关', 0),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pillAction(String label, int targetPos) {
    final isSelected = device.pos == targetPos;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSetPos(targetPos),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? (isWarm ? const Color(0xFF8C52FF) : TerminalTheme.purpleMode)
                : (isWarm ? TerminalTheme.warmButtonBg : TerminalTheme.borderSubtle),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFD1B3FF)
                  : (isWarm ? TerminalTheme.warmButtonBorder : Colors.transparent),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : (isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// 4. 热水器卡片
class TactileHeaterTile extends StatelessWidget {
  final HeaterDevice device;
  final bool isWarm;
  final VoidCallback onToggle;

  const TactileHeaterTile({
    super.key,
    required this.device,
    this.isWarm = false,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final active = device.on;
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active
              ? (isWarm ? TerminalTheme.warmCardActive : TerminalTheme.surfaceCardActive)
              : (isWarm ? TerminalTheme.warmCardBg : TerminalTheme.surfaceCard),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? const Color(0xFFFF5722).withValues(alpha: 0.6)
                : (isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.borderSubtle),
            width: active ? 1.5 : 1.0,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5722).withValues(alpha: 0.22),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFF5722).withValues(alpha: 0.2)
                        : (isWarm ? const Color(0x33443325) : Colors.white.withValues(alpha: 0.05)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: active ? const Color(0xFFFF5722) : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                    size: 18,
                  ),
                ),
                Text(
                  active ? '${device.powerWatts.toInt()}W' : '待机断电',
                  style: TextStyle(
                    color: active ? const Color(0xFFFF5722) : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  active ? '加热恒温中' : '回路切断',
                  style: TextStyle(
                    color: isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
