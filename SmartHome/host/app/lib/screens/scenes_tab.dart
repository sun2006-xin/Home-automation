import 'package:flutter/material.dart';
import '../models/cloud_device.dart';
import '../services/mi_cloud_service.dart';

class ScenesTab extends StatefulWidget {
  final MiCloudService cloud;

  const ScenesTab({super.key, required this.cloud});

  @override
  State<ScenesTab> createState() => _ScenesTabState();
}

class _ScenesTabState extends State<ScenesTab> {
  int _segmentIndex = 0;
  String? _runningSceneId;

  Future<void> _executeScene(ScenePreset scene) async {
    setState(() => _runningSceneId = scene.id);
    final err = await widget.cloud.triggerScene(scene.id);
    if (!mounted) return;
    setState(() => _runningSceneId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '已执行「${scene.name}」，所有终端与控制台已同步'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '智能场景',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _segBtn(0, '手动场景'),
                    _segBtn(1, '自动规则'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _segmentIndex == 0 ? _buildManualScenes() : _buildAutomationRules(),
        ),
      ],
    );
  }

  Widget _segBtn(int index, String label) {
    final selected = _segmentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _segmentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? const Color(0xFF1D1D1F) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildManualScenes() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: kMiScenes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final scene = kMiScenes[idx];
        final running = _runningSceneId == scene.id;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.025),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scene.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(scene.icon, color: scene.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scene.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scene.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: running ? null : () => _executeScene(scene),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00B589),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('执行', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutomationRules() {
    const rules = [
      ('壁挂终端实体快捷键联动', '当客厅中控按下「音量+」→ 触发回家模式；按下「音量-」→ 离家布防', true, '本地 + 云端同步'),
      ('室温超标自动降温守护', '当客厅传感器连续 3 分钟 ≥ 28.5°C 且人体传感器在室 → 开启客厅立柜空调 25°C', true, '云端边缘协同'),
      ('卫生间热水器防干烧定时', '加热达到保温阈值或持续 45 分钟后自动回落待机节能态', true, 'MCU 本地保护'),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      itemCount: rules.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final (title, desc, enabled, tag) = rules[idx];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    enabled ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                    color: enabled ? const Color(0xFF00B589) : const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73), height: 1.45),
              ),
            ],
          ),
        );
      },
    );
  }
}
