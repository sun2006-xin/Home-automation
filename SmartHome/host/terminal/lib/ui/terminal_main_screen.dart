import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/terminal_state.dart';
import '../core/device_model.dart';
import '../hal/hardware_key_service.dart';
import 'theme/terminal_theme.dart';
import 'widgets/ambient_background.dart';
import 'widgets/tactile_tiles.dart';
import 'widgets/physical_hud_overlay.dart';
import 'widgets/device_settings_modal.dart';

/// 2160x1080 横屏壁挂总控终端主屏幕 (Landscape Terminal Screen)
///
/// 核心人机工程学：
/// 1. 左侧【视距与安防控制锚点】(30% 宽度)：
///    - 巨幅极简数字时钟、环境温湿度胶囊、安防状态、硬件侧键指示与【设备管理设置入口】；
/// 2. 右侧【房间层叠与电器矩阵】(70% 宽度)：
///    - 顶部房间切换标签：全部 / 客厅 / 餐厅 / 主卧 / 卫生间，解决设备增多排不下的难题；
///    - 响应式自适应卡片矩阵：卡片动态适应宽高，彻底告别黄色溢出警告条；
/// 3. 全局包裹温馨家居微光背景 (AmbientHomeBackground)，告别冰冷死黑。
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
        final visibleDevices = widget.state.visibleDevices;

        return Scaffold(
          body: AmbientHomeBackground(
            isWarmMode: widget.state.useWarmHomeBackground,
            child: Stack(
              children: [
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ================= 左侧：生活环境与安防锚点 (30% 宽) =================
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131822).withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: TerminalTheme.borderSubtle),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 1. 视距时钟 (FittedBox 自适应绝不折行)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        timeStr,
                                        style: const TextStyle(
                                          color: TerminalTheme.textPrimary,
                                          fontSize: 48,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -1,
                                          height: 1.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        color: TerminalTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),

                                // 2. 环境温湿度与安防状态
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isAway
                                            ? TerminalTheme.purpleMode.withValues(alpha: 0.2)
                                            : TerminalTheme.tealSafe.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isAway ? TerminalTheme.purpleMode : TerminalTheme.tealSafe,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isAway ? Icons.shield_rounded : Icons.home_rounded,
                                            size: 15,
                                            color: isAway ? TerminalTheme.purpleMode : TerminalTheme.tealSafe,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isAway ? '全屋离家布防' : '居家守护中',
                                            style: TextStyle(
                                              color: isAway ? TerminalTheme.purpleMode : TerminalTheme.tealSafe,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // 紧凑型双温湿度胶囊 (绝不溢出)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.thermostat_rounded, size: 15, color: TerminalTheme.cyanCool),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${widget.state.sensors.indoorTemp}°C',
                                                style: const TextStyle(color: TerminalTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                          Container(width: 1, height: 12, color: Colors.white12),
                                          Row(
                                            children: [
                                              const Icon(Icons.water_drop_rounded, size: 14, color: TerminalTheme.cyanCool),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${widget.state.sensors.humidity.toInt()}%',
                                                style: const TextStyle(color: TerminalTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // 3. 物理按键 HUD 映射与配置入口
                                Column(
                                  children: [
                                    Row(
                                      children: [
                                        _keyChip('音量 +', '回家', () {
                                          HardwareKeyService().simulateKey(TerminalAction.homeMode);
                                        }),
                                        const SizedBox(width: 6),
                                        _keyChip('音量 -', '离家', () {
                                          HardwareKeyService().simulateKey(TerminalAction.awayMode);
                                        }),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    // 自主设置名称与房间入口
                                    GestureDetector(
                                      onTap: () => DeviceSettingsModal.show(context, widget.state),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white12),
                                        ),
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.tune_rounded, size: 15, color: TerminalTheme.amberWarm),
                                            SizedBox(width: 6),
                                            Text(
                                              '设备与房间设置',
                                              style: TextStyle(
                                                color: TerminalTheme.textPrimary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 18),

                        // ================= 右侧：房间层叠标签与电器矩阵 (70% 宽) =================
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              // 1. 房间层叠切换标签栏
                              SizedBox(
                                height: 42,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: widget.state.rooms.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                                  itemBuilder: (context, idx) {
                                    final room = widget.state.rooms[idx];
                                    final isSelected = room == widget.state.selectedRoom;
                                    final count = room == '全部'
                                        ? widget.state.allDevices.length
                                        : widget.state.allDevices.where((d) => d.room == room).length;

                                    return GestureDetector(
                                      onTap: () => widget.state.selectRoom(room),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? TerminalTheme.purpleMode
                                              : const Color(0xFF131822).withValues(alpha: 0.65),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: isSelected ? TerminalTheme.purpleMode : TerminalTheme.borderSubtle,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Text(
                                              room,
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : TerminalTheme.textSecondary,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.white24 : Colors.white10,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '$count',
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : TerminalTheme.textMuted,
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
                              ),

                              const SizedBox(height: 14),

                              // 2. 核心电器卡片弹性栅格 (彻底消灭溢出黄黑条)
                              Expanded(
                                child: visibleDevices.isEmpty
                                    ? _buildEmptyState()
                                    : GridView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3, // 横屏 3 列极佳视觉密度
                                          crossAxisSpacing: 12,
                                          mainAxisSpacing: 12,
                                          childAspectRatio: 1.25, // 宽卡片比例，防止文本溢出
                                        ),
                                        itemCount: visibleDevices.length,
                                        itemBuilder: (context, idx) {
                                          final dev = visibleDevices[idx];
                                          return buildDeviceTile(dev, widget.state);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 物理按键触发时滑出的浮动 HUD 涟漪
                PhysicalHudOverlay(notice: widget.state.physicalKeyNotice),
              ],
            ),
          ),
        );
      },
    );
  }



  Widget _keyChip(String keyLabel, String actionLabel, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: TerminalTheme.amberWarm.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  keyLabel,
                  style: const TextStyle(
                    color: TerminalTheme.amberWarm,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                actionLabel,
                style: const TextStyle(
                  color: TerminalTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.meeting_room_outlined, size: 48, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text(
            '该房间暂无配置电器',
            style: TextStyle(color: TerminalTheme.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
