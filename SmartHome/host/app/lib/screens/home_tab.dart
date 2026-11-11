import 'package:flutter/material.dart';
import '../models/cloud_device.dart';
import '../services/mi_cloud_service.dart';
import '../widgets/device_control_sheet.dart';
import '../widgets/device_grid_card.dart';

class HomeTab extends StatefulWidget {
  final MiCloudService cloud;

  const HomeTab({super.key, required this.cloud});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  String _selectedRoom = '全部';
  String? _triggeringSceneId;

  Future<void> _onSceneTap(ScenePreset scene) async {
    setState(() => _triggeringSceneId = scene.id);
    final err = await widget.cloud.triggerScene(scene.id);
    if (!mounted) return;
    setState(() => _triggeringSceneId = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? '已执行「${scene.name}」并同步至云端'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onQuickToggle(CloudDevice dev) async {
    final Map<String, dynamic> delta = dev.isCover
        ? {'pos': dev.coverPos > 0 ? 0 : 100}
        : {'on': !dev.isActive};
    final err = await widget.cloud.updateDeviceState(dev.id, delta);
    if (!mounted || err == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
    );
  }

  void _openDetail(CloudDevice dev) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceControlSheet(device: dev, cloud: widget.cloud),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.cloud,
      builder: (context, _) {
        final roomTabs = ['全部', ...widget.cloud.rooms];
        if (!roomTabs.contains(_selectedRoom)) {
          _selectedRoom = '全部';
        }
        final filtered = _selectedRoom == '全部'
            ? widget.cloud.devices
            : widget.cloud.devices.where((d) => d.room == _selectedRoom).toList();

        return RefreshIndicator(
          color: const Color(0xFF00B589),
          onRefresh: widget.cloud.refreshAll,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (widget.cloud.errorMessage != null)
                SliverToBoxAdapter(child: _buildErrorBanner(widget.cloud.errorMessage!)),
              SliverToBoxAdapter(child: _buildEnvironmentBanner()),
              SliverToBoxAdapter(child: _buildQuickScenesStrip()),
              SliverToBoxAdapter(child: _buildRoomFilterBar(roomTabs)),
              ..._buildGridSlivers(filtered),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final status = widget.cloud.connectionStatus;
    final Color dotColor;
    final String statusText;
    switch (status) {
      case AppCloudStatus.connected:
        dotColor = const Color(0xFF10B981);
        statusText = widget.cloud.latencyMs > 0 ? '云端 ${widget.cloud.latencyMs}ms' : '云端已同步';
        break;
      case AppCloudStatus.connecting:
        dotColor = const Color(0xFFF59E0B);
        statusText = '连接中';
        break;
      case AppCloudStatus.error:
      case AppCloudStatus.disconnected:
        dotColor = const Color(0xFFEF4444);
        statusText = '离线';
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Text(
                      '我的家',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 22, color: Color(0xFF1D1D1F)),
                  ],
                ),
                Text(
                  'Home ${widget.cloud.homeId} · ${widget.cloud.host}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF86868B)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
                ),
                const SizedBox(width: 6),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: widget.cloud.refreshAll,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            tooltip: '刷新状态',
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String err) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: Color(0xFFDC2626)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                err,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.cloud.refreshAll();
                widget.cloud.connectWebSocket();
              },
              child: const Text('重试', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnvironmentBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF0FDF9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFCCFBF1)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00B589).withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _envMetric('24.2°C', '室内温度', Icons.thermostat_rounded, const Color(0xFF00B589)),
            _divider(),
            _envMetric('53%', '相对湿度', Icons.water_drop_outlined, const Color(0xFF0EA5E9)),
            _divider(),
            _envMetric(
              '${widget.cloud.activeDeviceCount}/${widget.cloud.devices.length}',
              '运行设备',
              Icons.devices_other_rounded,
              const Color(0xFF0071E3),
            ),
            _divider(),
            _envMetric(
              '${widget.cloud.estimatedPowerWatts}W',
              '实时功耗',
              Icons.bolt_rounded,
              const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 26, color: const Color(0xFFE5E7EB));

  Widget _envMetric(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 2),
                  Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Color(0xFF86868B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickScenesStrip() {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: kMiScenes.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final scene = kMiScenes[index];
          final loading = _triggeringSceneId == scene.id;
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: loading ? null : () => _onSceneTap(scene),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(scene.icon, size: 17, color: scene.color),
                    const SizedBox(width: 6),
                    Text(
                      scene.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomFilterBar(List<String> roomTabs) {
    return Container(
      height: 46,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: roomTabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final room = roomTabs[idx];
          final selected = room == _selectedRoom;
          return GestureDetector(
            onTap: () => setState(() => _selectedRoom = room),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF1D1D1F) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? const Color(0xFF1D1D1F) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                room,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF6E6E73),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildGridSlivers(List<CloudDevice> list) {
    if (widget.cloud.isLoadingInitial) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    Container(height: 14, width: 90, color: const Color(0xFFF3F4F6)),
                    Container(height: 10, width: 65, color: const Color(0xFFF3F4F6)),
                  ],
                ),
              ),
              childCount: 6,
            ),
          ),
        ),
      ];
    }

    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.devices_fold_outlined, size: 40, color: Color(0xFF9CA3AF)),
                  const SizedBox(height: 10),
                  Text(
                    '「$_selectedRoom」暂无接入设备',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '下拉刷新或切换至「全部」查看所有全屋电器',
                    style: TextStyle(fontSize: 12, color: Color(0xFF86868B)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.94,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final dev = list[index];
              return DeviceGridCard(
                device: dev,
                isPending: widget.cloud.pendingDeviceIds.contains(dev.id),
                onQuickToggle: () => _onQuickToggle(dev),
                onOpenDetail: () => _openDetail(dev),
              );
            },
            childCount: list.length,
          ),
        ),
      ),
    ];
  }
}
