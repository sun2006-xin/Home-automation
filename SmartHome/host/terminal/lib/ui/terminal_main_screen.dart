import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/terminal_state.dart';
import '../core/device_model.dart';
import 'theme/terminal_theme.dart';
import 'widgets/ambient_background.dart';
import 'widgets/category_cluster_deck.dart';
import 'widgets/room_appliances_deck.dart';
import 'widgets/physical_hud_overlay.dart';
import 'widgets/device_settings_modal.dart';

/// 2160x1080 横屏壁挂总控终端主屏幕 (Landscape Terminal Screen)
///
/// 核心人机工效与架构升级（彻底告别左右分栏，拥抱纯粹的【从上往下】层级视线流）：
/// 1. 【顶层导航与状态总览栏】(Top Bar，先看顶部)：
///    - 明确标识【智慧家居终端】主标题与物理链路状态；
///    - 实时时钟、温湿度环境胶囊、安防模式、物理按键操作指引与设置入口；
/// 2. 【上层：第一层·全物品类聚合卡片】(Upper Deck，同种品类同一张卡片，卡内左右切换)：
///    - 💡 照明系统、❄️ 暖通环控、🪟 遮阳系统、⚡ 动力用水；
/// 3. 【下层：第二层·多房间层叠切换与专属电器流】(Lower Deck，房间切换看具体电器)：
///    - 客厅、主卧、次卧(南)、次卧(北)、书房、餐厅、卫生间流式切换，展示房间内电器；
/// 4. 【温馨家庭实景背景】(AmbientHomeBackground)：
///    - 加载真实家庭实景壁纸 + 护眼毛玻璃漫反射遮罩，告别死黑，温馨舒适。
class TerminalMainScreen extends StatefulWidget {
  final TerminalState state;

  const TerminalMainScreen({super.key, required this.state});

  @override
  State<TerminalMainScreen> createState() => _TerminalMainScreenState();
}

class _TerminalMainScreenState extends State<TerminalMainScreen> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final timeStr = DateFormat('HH:mm').format(widget.state.now);
        final dateStr = DateFormat('MM月dd日 EEEE', 'zh_CN').format(widget.state.now);
        final isAway = widget.state.securityMode == SecurityMode.awayArmed;

        return Scaffold(
          body: AmbientHomeBackground(
            isWarmMode: widget.state.useWarmHomeBackground,
            child: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ================= 1. 顶部总览栏：智慧家居终端 + 时钟 + 传感器 + 设置 =================
                        _buildTopHeaderBar(timeStr, dateStr, isAway),
                        const SizedBox(height: 6),

                        // ================= 2. 上部第一层：品类中控聚合卡片 (卡内左右切换) =================
                        CategoryClusterDeck(state: widget.state),
                        const SizedBox(height: 6),

                        // ================= 3. 下部第二层：房间分区层叠切换与房间专属电器 =================
                        Expanded(
                          child: RoomAppliancesDeck(state: widget.state),
                        ),
                      ],
                    ),
                  ),
                ),

                // 物理按键瞬态 HUD 浮层 (按音量键时优雅浮现)
                PhysicalHudOverlay(notice: widget.state.physicalKeyNotice),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部导航与状态总览栏
  Widget _buildTopHeaderBar(String timeStr, String dateStr, bool isAway) {
    final isWarm = widget.state.useWarmHomeBackground;

    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isWarm ? TerminalTheme.warmTopBarBg : const Color(0xFF131822).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.glassBorder,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          // 终端主标题：智慧家居终端
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWarm ? TerminalTheme.amberWarm : const Color(0xFF00E676),
                  boxShadow: [
                    BoxShadow(
                      color: isWarm ? TerminalTheme.amberWarm : const Color(0xFF00E676),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '智慧家居终端',
                style: TextStyle(
                  color: isWarm ? TerminalTheme.warmTextPrimary : Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // 安防守护状态 Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: isAway
                  ? (isWarm ? const Color(0x66B33927) : const Color(0xFF6C5CE7).withValues(alpha: 0.25))
                  : (isWarm ? const Color(0x554A3B2C) : const Color(0xFF00E676).withValues(alpha: 0.15)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isAway
                    ? (isWarm ? const Color(0xFFE17055) : const Color(0xFFA29BFE))
                    : (isWarm ? TerminalTheme.amberWarm : const Color(0xFF00E676).withValues(alpha: 0.5)),
              ),
            ),
            child: Text(
              isAway ? '🛡️ 离家布防' : '🏠 居家守护',
              style: TextStyle(
                color: isAway
                    ? (isWarm ? const Color(0xFFFAB1A0) : const Color(0xFFA29BFE))
                    : (isWarm ? TerminalTheme.amberWarm : const Color(0xFF00E676)),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const Spacer(),

          // 中间：时间与温湿度胶囊
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  color: isWarm ? TerminalTheme.warmTextPrimary : Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: TextStyle(
                  color: isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 12),
              // 环境传感器
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isWarm ? const Color(0x4036271D) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWarm ? TerminalTheme.warmCardBorder.withValues(alpha: 0.4) : Colors.transparent,
                  ),
                ),
                child: Text(
                  '🌡️ ${widget.state.sensors.indoorTemp.toStringAsFixed(1)}°C  💧 ${widget.state.sensors.humidity.toInt()}%',
                  style: TextStyle(
                    color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.textPrimary,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 右侧：物理按键指引
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildKeyGuideChip('音量+', '回家', isWarm),
              const SizedBox(width: 4),
              _buildKeyGuideChip('音量-', '离家', isWarm),
            ],
          ),
          const SizedBox(width: 8),

          // 设置管理入口
          GestureDetector(
            onTap: () => _openSettingsModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isWarm
                    ? TerminalTheme.warmButtonActive.withValues(alpha: 0.3)
                    : TerminalTheme.amberPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isWarm
                      ? TerminalTheme.warmCardBorder
                      : TerminalTheme.amberPrimary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.amberPrimary,
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '设置',
                    style: TextStyle(
                      color: isWarm ? TerminalTheme.warmTextPrimary : TerminalTheme.amberPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyGuideChip(String keyLabel, String actionLabel, bool isWarm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isWarm ? const Color(0x4036271D) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isWarm ? TerminalTheme.warmCardBorder.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyLabel,
            style: TextStyle(
              color: isWarm ? TerminalTheme.amberWarm : TerminalTheme.amberPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            actionLabel,
            style: TextStyle(
              color: isWarm ? TerminalTheme.warmTextSecondary : TerminalTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  void _openSettingsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceSettingsModal(state: widget.state),
    );
  }
}
