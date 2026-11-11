import 'package:flutter/material.dart';
import '../services/mi_cloud_service.dart';

class DiscoverTab extends StatelessWidget {
  final MiCloudService cloud;

  const DiscoverTab({super.key, required this.cloud});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cloud,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            const Text(
              '空间拓扑与硬件网关',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
            ),
            const SizedBox(height: 4),
            const Text(
              '统一展示全屋多朝向空间分布与边缘节点接入健康度',
              style: TextStyle(fontSize: 12, color: Color(0xFF86868B)),
            ),
            const SizedBox(height: 16),
            const Text(
              '房间设备清单',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
            ),
            const SizedBox(height: 10),
            ...cloud.rooms.map((room) {
              final devs = cloud.devices.where((d) => d.room == room).toList();
              final active = devs.where((d) => d.isActive).length;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.meeting_room_rounded, color: Color(0xFF00B589)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            room,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            devs.isEmpty
                                ? '暂无绑定电器'
                                : devs.map((e) => e.name).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: active > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$active/${devs.length} 运行',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active > 0 ? const Color(0xFF059669) : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              '云端托管网关与 MCU 架构',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
            ),
            const SizedBox(height: 10),
            _nodeCard(
              'SmartHome Cloud Hub',
              'REST/JSON + WebSocket Duplex · 端口 ${cloud.port}',
              '已接入 ${cloud.activeClients} 个活跃客户端',
              Icons.cloud_done_rounded,
              const Color(0xFF0071E3),
            ),
            const SizedBox(height: 10),
            _nodeCard(
              '壁挂智能中控屏 (Kiosk)',
              '客厅固定壁挂端子 · 物理音量键盲操绑定',
              'WebSocket /ws/terminal?client_id=terminal_screen',
              Icons.tablet_android_rounded,
              const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _nodeCard(
              '异构 MCU 驱动节点矩阵',
              'ESP32-C3 (Wi-Fi/MQTT) + STM32F4 (UART/HAL 板级自适应)',
              '支持通过 PC 烧录工坊统一管理引脚映射与屏幕适配',
              Icons.memory_rounded,
              const Color(0xFF6366F1),
            ),
          ],
        );
      },
    );
  }

  Widget _nodeCard(String title, String sub, String foot, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(sub, style: const TextStyle(fontSize: 12, color: Color(0xFF6E6E73))),
                const SizedBox(height: 4),
                Text(foot, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
