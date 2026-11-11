import 'package:flutter/material.dart';
import '../models/cloud_device.dart';

class DeviceGridCard extends StatelessWidget {
  final CloudDevice device;
  final bool isPending;
  final VoidCallback onQuickToggle;
  final VoidCallback onOpenDetail;

  const DeviceGridCard({
    super.key,
    required this.device,
    required this.isPending,
    required this.onQuickToggle,
    required this.onOpenDetail,
  });

  String _formatUpdatedTime(double epochSec) {
    if (epochSec <= 0) return '--:--';
    final dt = DateTime.fromMillisecondsSinceEpoch((epochSec * 1000).round());
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final active = device.isActive;
    final accent = device.accentColor;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: isPending ? 0.65 : 1.0,
      child: Material(
        color: active ? Colors.white : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          onTap: onOpenDetail,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? accent.withOpacity(0.28) : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.025),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: active ? accent.withOpacity(0.14) : const Color(0xFFF1F3F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        device.iconData,
                        size: 20,
                        color: active ? accent : const Color(0xFF9CA3AF),
                      ),
                    ),
                    _buildQuickButton(active, accent),
                  ],
                ),
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${device.room} · ${device.statusLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        color: active ? accent : const Color(0xFF86868B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: active ? const Color(0xFF10B981) : const Color(0xFFD1D5DB),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${device.id} · ${_formatUpdatedTime(device.updatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickButton(bool active, Color accent) {
    if (isPending) {
      return const SizedBox(
        width: 34,
        height: 34,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (device.isCover) {
      return InkWell(
        onTap: onQuickToggle,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? accent.withOpacity(0.12) : const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            active ? '合拢' : '打开',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? accent : const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    return Material(
      color: active ? accent : const Color(0xFFF1F3F5),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onQuickToggle,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.power_settings_new_rounded,
            size: 18,
            color: active ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
