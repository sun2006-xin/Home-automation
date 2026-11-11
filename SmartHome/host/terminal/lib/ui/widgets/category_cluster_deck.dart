import 'package:flutter/material.dart';
import '../../core/device_model.dart';
import '../../core/terminal_state.dart';
import '../theme/terminal_theme.dart';

/// 第一层：全物品类聚合卡片组 (Category Cluster Deck)
///
/// 核心交互设计：
/// 1. 按家电品类划分为 4 张主卡片：【💡 照明系统】、【❄️ 暖通环控】、【🪟 遮阳系统】、【⚡ 动力用水】；
/// 2. 同种品类家电汇聚于同一张卡片内，卡片顶部带左右切换器 (◀ 1/N ▶)，可顺畅切换同一品类的不同电器；
/// 3. 卡内直接集成高频快捷操控（开/关、调温、全开全关、功率状态），实现高密度触控与高效盲操。
class CategoryClusterDeck extends StatelessWidget {
  final TerminalState state;

  const CategoryClusterDeck({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 照明品类卡
          Expanded(child: _buildLightingCard()),
          const SizedBox(width: 8),

          // 2. 暖通品类卡
          Expanded(child: _buildClimateCard()),
          const SizedBox(width: 8),

          // 3. 遮阳品类卡
          Expanded(child: _buildCoverCard()),
          const SizedBox(width: 8),

          // 4. 动力与用水品类卡
          Expanded(child: _buildPowerCard()),
        ],
      ),
    );
  }

  // --- 1. 照明系统聚合卡 ---
  Widget _buildLightingCard() {
    final lights = state.lightDevices;
    if (lights.isEmpty) {
      return _buildEmptyCard('💡 照明系统', '暂无照明设备');
    }
    final activeCount = lights.where((l) => l.on).length;
    final currentIndex = state.lightIndex.clamp(0, lights.length - 1);
    final currentLight = lights[currentIndex];

    return _CategoryCardContainer(
      isWarm: state.useWarmHomeBackground,
      borderColor: currentLight.on
          ? TerminalTheme.amberWarm.withValues(alpha: 0.5)
          : TerminalTheme.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 卡片头：品类名 + 数量统计 + 卡内切换器
          _buildCardHeader(
            icon: Icons.lightbulb_rounded,
            iconColor: TerminalTheme.amberWarm,
            title: '照明系统',
            badge: '$activeCount/${lights.length} 开启',
            onPrev: () => state.prevLight(),
            onNext: () => state.nextLight(),
            pageIndicator: '${currentIndex + 1}/${lights.length}',
          ),
          const Spacer(),

          // 当前选中的灯具信息与切换触控
          Row(
            children: [
              // 状态灯泡
              GestureDetector(
                onTap: () => state.toggleSwitch(currentLight),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: currentLight.on
                        ? TerminalTheme.amberWarm.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    border: Border.all(
                      color: currentLight.on
                          ? TerminalTheme.amberWarm
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    currentLight.on
                        ? Icons.lightbulb
                        : Icons.lightbulb_outline,
                    color: currentLight.on
                        ? TerminalTheme.amberWarm
                        : TerminalTheme.textMuted,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 设备名称与房间标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentLight.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            currentLight.room,
                            style: const TextStyle(
                              color: TerminalTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          currentLight.on ? '已通电' : '切断',
                          style: TextStyle(
                            color: currentLight.on
                                ? TerminalTheme.amberWarm
                                : TerminalTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // 底部快捷栏：一键全开 / 全关
          Row(
            children: [
              Expanded(
                child: _buildMiniActionButton(
                  label: currentLight.on ? '关闭此灯' : '开启此灯',
                  active: currentLight.on,
                  activeColor: TerminalTheme.amberWarm,
                  onTap: () => state.toggleSwitch(currentLight),
                ),
              ),
              const SizedBox(width: 4),
              _buildMiniActionButton(
                label: '全关',
                onTap: () => state.toggleAllLights(false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 2. 暖通环控聚合卡 ---
  Widget _buildClimateCard() {
    final climates = state.climateDevices;
    if (climates.isEmpty) {
      return _buildEmptyCard('❄️ 暖通环控', '暂无暖通设备');
    }
    final currentIndex = state.climateIndex.clamp(0, climates.length - 1);
    final dev = climates[currentIndex];

    final bool isClimate = dev is ClimateDevice;
    final bool isOn = isClimate ? dev.on : (dev as SwitchDevice).on;
    final SwitchDevice? fan = isClimate ? null : (dev as SwitchDevice);

    return _CategoryCardContainer(
      isWarm: state.useWarmHomeBackground,
      borderColor: isOn
          ? TerminalTheme.cyanCool.withValues(alpha: 0.5)
          : TerminalTheme.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.ac_unit_rounded,
            iconColor: TerminalTheme.cyanCool,
            title: '暖通环控',
            badge: '${climates.length} 台设备',
            onPrev: () => state.prevClimate(),
            onNext: () => state.nextClimate(),
            pageIndicator: '${currentIndex + 1}/${climates.length}',
          ),
          const Spacer(),

          // 中部核心调节
          if (isClimate) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${dev.room} · ${isOn ? "运行中" : "已关机"}',
                        style: TextStyle(
                          color: isOn ? TerminalTheme.cyanCool : TerminalTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  isOn ? '${dev.targetTemp.toStringAsFixed(1)}°' : '--',
                  style: TextStyle(
                    color: isOn ? TerminalTheme.cyanCool : TerminalTheme.textMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // 温度加减与电源
            Row(
              children: [
                _buildSquareStepButton('-', () => state.adjustClimateTemp(dev, -0.5)),
                const SizedBox(width: 4),
                _buildSquareStepButton('+', () => state.adjustClimateTemp(dev, 0.5)),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildMiniActionButton(
                    label: isOn ? '关机' : '开启制冷',
                    active: isOn,
                    activeColor: TerminalTheme.cyanCool,
                    onTap: () => state.toggleClimate(dev),
                  ),
                ),
              ],
            ),
          ] else if (fan != null) ...[
            // 风扇类型
            Row(
              children: [
                Icon(
                  Icons.mode_fan_off_rounded,
                  color: fan.on ? TerminalTheme.cyanCool : TerminalTheme.textMuted,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fan.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                      ),
                      Text(
                        '${fan.room} · ${fan.on ? "柔风运转" : "已切断"}',
                        style: TextStyle(
                          color: fan.on ? TerminalTheme.cyanCool : TerminalTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            _buildMiniActionButton(
              label: fan.on ? '停止运转' : '启动风扇',
              active: fan.on,
              activeColor: TerminalTheme.cyanCool,
              onTap: () => state.toggleSwitch(fan),
            ),
          ],
        ],
      ),
    );
  }

  // --- 3. 遮阳门窗聚合卡 ---
  Widget _buildCoverCard() {
    final covers = state.coverDevices;
    if (covers.isEmpty) {
      return _buildEmptyCard('🪟 遮阳系统', '暂无窗帘设备');
    }
    final currentIndex = state.coverIndex.clamp(0, covers.length - 1);
    final curCover = covers[currentIndex];

    return _CategoryCardContainer(
      isWarm: state.useWarmHomeBackground,
      borderColor: curCover.pos > 0
          ? const Color(0xFFB388FF).withValues(alpha: 0.5)
          : TerminalTheme.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.curtains_rounded,
            iconColor: const Color(0xFFB388FF),
            title: '遮阳系统',
            badge: '${curCover.pos}% 开启',
            onPrev: () => state.prevCover(),
            onNext: () => state.nextCover(),
            pageIndicator: '${currentIndex + 1}/${covers.length}',
          ),
          const Spacer(),

          // 窗帘名称与开度
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curCover.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1,
                    ),
                    Text(
                      '${curCover.room} · 行程定位',
                      style: const TextStyle(color: TerminalTheme.textMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Text(
                '${curCover.pos}%',
                style: const TextStyle(
                  color: Color(0xFFB388FF),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),

          // 全开、半开、全关快捷按钮
          Row(
            children: [
              Expanded(
                child: _buildMiniActionButton(
                  label: '全开',
                  active: curCover.pos >= 95,
                  activeColor: const Color(0xFFB388FF),
                  onTap: () => state.setCoverPos(curCover, 100),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMiniActionButton(
                  label: '半开',
                  active: curCover.pos >= 40 && curCover.pos <= 60,
                  activeColor: const Color(0xFFB388FF),
                  onTap: () => state.setCoverPos(curCover, 50),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildMiniActionButton(
                  label: '全关',
                  active: curCover.pos == 0,
                  activeColor: const Color(0xFFB388FF),
                  onTap: () => state.setCoverPos(curCover, 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 4. 动力与用水聚合卡 ---
  Widget _buildPowerCard() {
    final powers = state.powerDevices;
    if (powers.isEmpty) {
      return _buildEmptyCard('⚡ 动力用水', '暂无动力设备');
    }
    final currentIndex = state.powerIndex.clamp(0, powers.length - 1);
    final curDev = powers[currentIndex];

    final bool isHeater = curDev is HeaterDevice;
    final bool isOn = isHeater ? curDev.on : (curDev as SwitchDevice).on;
    final SwitchDevice? socket = isHeater ? null : (curDev as SwitchDevice);

    return _CategoryCardContainer(
      isWarm: state.useWarmHomeBackground,
      borderColor: isOn
          ? Colors.orangeAccent.withValues(alpha: 0.5)
          : TerminalTheme.glassBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            icon: Icons.electric_bolt_rounded,
            iconColor: Colors.orangeAccent,
            title: '动力用水',
            badge: '${powers.length} 设备',
            onPrev: () => state.prevPower(),
            onNext: () => state.nextPower(),
            pageIndicator: '${currentIndex + 1}/${powers.length}',
          ),
          const Spacer(),

          if (isHeater) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curDev.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                      ),
                      Text(
                        curDev.on
                            ? '${curDev.powerWatts.toInt()}W · 恒温加热'
                            : '${curDev.room} · 待机断电',
                        style: TextStyle(
                          color: curDev.on ? Colors.orangeAccent : TerminalTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.water_drop_rounded,
                  color: curDev.on ? Colors.orangeAccent : TerminalTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            _buildMiniActionButton(
              label: curDev.on ? '关闭速热' : '开启速热 (2000W)',
              active: curDev.on,
              activeColor: Colors.orangeAccent,
              onTap: () => state.toggleHeater(curDev),
            ),
          ] else if (socket != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        socket.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        maxLines: 1,
                      ),
                      Text(
                        '${socket.room} · ${socket.on ? "插座通电" : "已切断"}',
                        style: TextStyle(
                          color: socket.on ? Colors.orangeAccent : TerminalTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.power_rounded,
                  color: socket.on ? Colors.orangeAccent : TerminalTheme.textMuted,
                  size: 20,
                ),
              ],
            ),
            const Spacer(),
            _buildMiniActionButton(
              label: socket.on ? '断电' : '通电',
              active: socket.on,
              activeColor: Colors.orangeAccent,
              onTap: () => state.toggleSwitch(socket),
            ),
          ],
        ],
      ),
    );
  }

  // --- 辅助组件 ---

  Widget _buildCardHeader({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badge,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required String pageIndicator,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 4),
        // 翻页器
        GestureDetector(
          onTap: onPrev,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white, size: 14),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          pageIndicator,
          style: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 10),
        ),
        const SizedBox(width: 3),
        GestureDetector(
          onTap: onNext,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.chevron_right, color: Colors.white, size: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String title, String subtitle) {
    return _CategoryCardContainer(
      isWarm: state.useWarmHomeBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: TerminalTheme.textMuted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSquareStepButton(String symbol, VoidCallback onTap) {
    final isWarm = state.useWarmHomeBackground;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 26,
        decoration: BoxDecoration(
          color: isWarm ? TerminalTheme.warmButtonBg : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: isWarm ? TerminalTheme.warmButtonBorder : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(
              color: isWarm ? TerminalTheme.warmTextPrimary : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniActionButton({
    required String label,
    bool active = false,
    Color activeColor = TerminalTheme.amberWarm,
    required VoidCallback onTap,
  }) {
    final isWarm = state.useWarmHomeBackground;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: active
              ? (isWarm ? activeColor.withValues(alpha: 0.35) : activeColor.withValues(alpha: 0.25))
              : (isWarm ? TerminalTheme.warmButtonBg : Colors.white.withValues(alpha: 0.06)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active
                ? activeColor.withValues(alpha: 0.8)
                : (isWarm ? TerminalTheme.warmButtonBorder : Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active
                  ? activeColor
                  : (isWarm ? TerminalTheme.warmTextSecondary : Colors.white),
              fontSize: 11,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

/// 品类卡片磨砂玻璃统一容器
class _CategoryCardContainer extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  final bool isWarm;

  const _CategoryCardContainer({
    required this.child,
    this.borderColor,
    this.isWarm = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isWarm
            ? TerminalTheme.warmCardBg
            : const Color(0xFF131822).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? (isWarm ? TerminalTheme.warmCardBorder : TerminalTheme.glassBorder),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isWarm ? const Color(0x33120A05) : Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
