import 'package:flutter/material.dart';
import '../services/mi_cloud_service.dart';

class ProfileTab extends StatefulWidget {
  final MiCloudService cloud;

  const ProfileTab({super.key, required this.cloud});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late TextEditingController _hostCtrl;
  late TextEditingController _portCtrl;

  @override
  void initState() {
    super.initState();
    _hostCtrl = TextEditingController(text: widget.cloud.host);
    _portCtrl = TextEditingController(text: widget.cloud.port.toString());
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveEndpoint() async {
    final host = _hostCtrl.text.trim();
    final port = int.tryParse(_portCtrl.text.trim()) ?? 8000;
    if (host.isEmpty) return;
    await widget.cloud.configureEndpoint(host, port);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已切换云端节点至 $host:$port'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.cloud,
      builder: (context, _) {
        final connected = widget.cloud.connectionStatus == AppCloudStatus.connected;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00B589), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, size: 32, color: Color(0xFF00B589)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '智慧家庭管理员',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '租户 ${widget.cloud.homeId} · ${connected ? '全双工长连接在线' : '等待重连云端'}',
                          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '云端服务器地址配置（PC 端或公网 VPS）',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1D1D1F)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '开发阶段填电脑局域网 IP；部署到公网云服务器直接填域名或公网 IP 即可跨网同步',
                    style: TextStyle(fontSize: 12, color: Color(0xFF86868B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _hostCtrl,
                          decoration: InputDecoration(
                            labelText: '云端主机 / IP / 域名',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 96,
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '端口',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('开发 PC (192.168.1.12)'),
                        onPressed: () {
                          _hostCtrl.text = '192.168.1.12';
                          _portCtrl.text = '8000';
                        },
                      ),
                      ActionChip(
                        label: const Text('模拟器环回 (127.0.0.1)'),
                        onPressed: () {
                          _hostCtrl.text = '127.0.0.1';
                          _portCtrl.text = '8000';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saveEndpoint,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0071E3),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.cloud_sync_rounded, size: 18),
                      label: const Text('应用地址并全量拉取同步', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '实时通信事件流水',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        widget.cloud.latencyMs > 0 ? 'RTT ${widget.cloud.latencyMs}ms' : '--',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (widget.cloud.eventLogs.isEmpty)
                    const Text('暂无信令日志', style: TextStyle(fontSize: 12, color: Color(0xFF86868B)))
                  else
                    ...widget.cloud.eventLogs.take(10).map(
                      (line) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Color(0xFF4B5563)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
