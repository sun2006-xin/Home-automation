import 'package:flutter/material.dart';
import '../models/cloud_device.dart';
import '../services/mi_cloud_service.dart';

class DeviceControlSheet extends StatefulWidget {
  final CloudDevice device;
  final MiCloudService cloud;

  const DeviceControlSheet({
    super.key,
    required this.device,
    required this.cloud,
  });

  @override
  State<DeviceControlSheet> createState() => _DeviceControlSheetState();
}

class _DeviceControlSheetState extends State<DeviceControlSheet> {
  List<Map<String, dynamic>> _telemetry = [];
  bool _loadingHistory = true;
  double? _draggingCoverPos;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final rows = await widget.cloud.fetchTelemetry(widget.device.id);
    if (!mounted) return;
    setState(() {
      _telemetry = rows;
      _loadingHistory = false;
    });
  }

  Future<void> _send(Map<String, dynamic> delta) async {
    final err = await widget.cloud.updateDeviceState(widget.device.id, delta);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
      );
    } else {
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.cloud,
      builder: (context, _) {
        final dev = widget.cloud.devices.firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );
        final active = dev.isActive;
        final accent = dev.accentColor;

        return SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.84,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: active ? accent.withOpacity(0.14) : const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          dev.iconData,
                          color: active ? accent : const Color(0xFF6B7280),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dev.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1D1D1F),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${dev.room} · ${dev.statusLabel} · ID ${dev.id}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6E6E73),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF6E6E73)),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildControlPanel(dev, active, accent),
                        const SizedBox(height: 16),
                        _buildAuditSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlPanel(CloudDevice dev, bool active, Color accent) {
    if (dev.isClimate) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '空调运行控制',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF6E6E73)),
                ),
                Switch.adaptive(
                  value: active,
                  activeColor: accent,
                  onChanged: (v) => _send({'on': v}),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${dev.targetTemp.toStringAsFixed(1)}°C',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: active ? accent : const Color(0xFF9CA3AF),
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleAdjustButton(Icons.remove_rounded, () {
                  final next = (dev.targetTemp - 0.5).clamp(16.0, 31.0);
                  _send({'on': true, 'targetTemp': next});
                }),
                const SizedBox(width: 24),
                _circleAdjustButton(Icons.add_rounded, () {
                  final next = (dev.targetTemp + 0.5).clamp(16.0, 31.0);
                  _send({'on': true, 'targetTemp': next});
                }),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _modeButton('cool', '制冷', dev.climateMode, accent),
                const SizedBox(width: 8),
                _modeButton('heat', '制热', dev.climateMode, accent),
                const SizedBox(width: 8),
                _modeButton('fan', '送风', dev.climateMode, accent),
              ],
            ),
          ],
        ),
      );
    }

    if (dev.isCover) {
      final sliderVal = _draggingCoverPos ?? dev.coverPos.toDouble();
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              '${sliderVal.round()}%',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 6),
            const Text('拖动调节窗帘开合行程', style: TextStyle(fontSize: 12, color: Color(0xFF86868B))),
            Slider(
              value: sliderVal,
              min: 0,
              max: 100,
              divisions: 20,
              activeColor: accent,
              onChanged: (v) => setState(() => _draggingCoverPos = v),
              onChangeEnd: (v) {
                setState(() => _draggingCoverPos = null);
                _send({'pos': v.round()});
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _presetChip('全开 100%', () => _send({'pos': 100}), dev.coverPos == 100, accent),
                const SizedBox(width: 8),
                _presetChip('半开 50%', () => _send({'pos': 50}), dev.coverPos == 50, accent),
                const SizedBox(width: 8),
                _presetChip('全关 0%', () => _send({'pos': 0}), dev.coverPos == 0, accent),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _send({'on': !active}),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? accent : const Color(0xFFF1F5F9),
                boxShadow: active
                    ? [BoxShadow(color: accent.withOpacity(0.32), blurRadius: 20, offset: const Offset(0, 8))]
                    : null,
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                size: 40,
                color: active ? Colors.white : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            active ? '设备运行中 · 点击断电关闭' : '设备已待机 · 点击立即开启',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1D1D1F)),
          ),
          if (dev.isHeater && active) ...[
            const SizedBox(height: 6),
            Text(
              '当前功率 ${dev.powerWatts.toInt()}W · 预计剩余 ${dev.remainingMinutes} 分钟',
              style: const TextStyle(fontSize: 12, color: Color(0xFFF97316)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _circleAdjustButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF1F3F5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Icon(icon, size: 24, color: const Color(0xFF1D1D1F)),
        ),
      ),
    );
  }

  Widget _modeButton(String mode, String label, String current, Color accent) {
    final selected = mode == current;
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _send({'on': true, 'mode': mode}),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? accent : Colors.white,
          foregroundColor: selected ? Colors.white : const Color(0xFF4B5563),
          side: BorderSide(color: selected ? accent : const Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _presetChip(String label, VoidCallback onTap, bool selected, Color accent) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? accent.withOpacity(0.12) : Colors.white,
          foregroundColor: selected ? accent : const Color(0xFF4B5563),
          side: BorderSide(color: selected ? accent : const Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildAuditSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '云端操作轨迹（谁在何时操控）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
          ),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_telemetry.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '暂无云端历史记录，调节开关后自动录制。',
                style: TextStyle(fontSize: 12, color: Color(0xFF86868B)),
              ),
            )
          else
            ..._telemetry.take(8).map((row) {
              final st = Map<String, dynamic>.from(row['state'] as Map? ?? {});
              final src = (row['src'] ?? 'cloud').toString();
              final ts = (row['created_at'] is num) ? (row['created_at'] as num).toDouble() : 0.0;
              final dt = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round());
              final timeStr =
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';

              final actionDesc = st.containsKey('pos')
                  ? '开合度 ${st['pos']}%'
                  : (st.containsKey('targetTemp')
                      ? '${st['on'] == true ? '开启' : '关闭'} · ${st['targetTemp']}°C'
                      : (st['on'] == true ? '已开启' : '已关闭'));

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$actionDesc · 来源 $src',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
