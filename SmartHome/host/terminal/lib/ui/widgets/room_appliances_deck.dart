import 'package:flutter/material.dart';
import '../../core/device_model.dart';
import '../../core/terminal_state.dart';
import '../theme/terminal_theme.dart';
import 'tactile_tiles.dart';

/// 第二层：房间分区层叠切换与专属电器流 (Room Appliances Deck)
///
/// 核心交互设计：
/// 1. 顶部提供多房间胶囊切换条：【全部】、【客厅】、【主卧】、【次卧(南)】、【次卧(北)】、【书房】、【餐厅】、【卫生间】；
/// 2. 点击任一房间胶囊，下方即刻展现该房间的具体所有电器清单（客厅有什么、厕所有什么一目了然）；
/// 3. 卡片支持横向弹性滚动，无论单房间拥有多少电器，均从容横向排布，具备舒适的触控手感与零溢出保证。
class RoomAppliancesDeck extends StatelessWidget {
  final TerminalState state;

  const RoomAppliancesDeck({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final visibleDevices = state.visibleDevices;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 房间分类胶囊选择条
        _buildRoomTabBar(),
        const SizedBox(height: 6),

        // 2. 所选房间专属电器横向卡片流
        Expanded(
          child: visibleDevices.isEmpty
              ? _buildEmptyRoomPlaceholder()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: visibleDevices.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final device = visibleDevices[index];
                    return SizedBox(
                      width: 175,
                      child: _buildDeviceTile(device),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 房间胶囊切换条
  Widget _buildRoomTabBar() {
    return SizedBox(
      height: 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: state.rooms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final room = state.rooms[index];
          final isSelected = state.selectedRoom == room;
          final count = room == '全部'
              ? state.allDevices.length
              : state.allDevices.where((d) => d.room == room).length;

          final isWarm = state.useWarmHomeBackground;

          return GestureDetector(
            onTap: () => state.selectRoom(room),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isWarm ? TerminalTheme.warmPillActive : const Color(0xFF6C5CE7))
                    : (isWarm ? TerminalTheme.warmCardBg : const Color(0xFF161A26).withValues(alpha: 0.75)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? (isWarm ? const Color(0xFFFFD180) : const Color(0xFFA29BFE))
                      : (isWarm ? TerminalTheme.warmCardBorder : Colors.white.withValues(alpha: 0.08)),
                  width: isSelected ? 1.4 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: isWarm
                              ? const Color(0x66C87D32)
                              : const Color(0xFF6C5CE7).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    room,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.25)
                          : (isWarm ? const Color(0x4036271D) : Colors.white.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isWarm ? TerminalTheme.warmTextMuted : TerminalTheme.textMuted),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 房间专属卡片渲染
  Widget _buildDeviceTile(SmartDevice device) {
    return buildDeviceTile(device, state);
  }

  Widget _buildEmptyRoomPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131822).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TerminalTheme.glassBorder),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, color: TerminalTheme.textMuted, size: 18),
            const SizedBox(width: 8),
            Text(
              '当前【${state.selectedRoom}】暂未分配任何智能电器，可点击右上角设置进行分配',
              style: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
