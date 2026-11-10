import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/terminal_state.dart';
import '../../core/device_model.dart';
import '../../core/cloud_sync_service.dart';
import '../theme/terminal_theme.dart';

/// 设备与房间自主配置面板 (DeviceSettingsModal)
///
/// 架构升级：
/// 1. 支持多卧室与方位朝向房间管理（主卧、次卧南、次卧北、书房等，支持自由增删）；
/// 2. 自主编辑任意电器的显示名称、硬件 ID 与归属房间（所选房间实时联动）；
/// 3. 温馨家居实景背景壁纸开关与环境微光控制。
class DeviceSettingsModal extends StatefulWidget {
  final TerminalState state;

  const DeviceSettingsModal({super.key, required this.state});

  @override
  State<DeviceSettingsModal> createState() => _DeviceSettingsModalState();
}

class _DeviceSettingsModalState extends State<DeviceSettingsModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _newRoomController = TextEditingController();
  late TextEditingController _cloudHostController;
  late TextEditingController _cloudPortController;
  late TextEditingController _cloudTokenController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cloudHostController = TextEditingController(text: widget.state.cloudSync.host);
    _cloudPortController = TextEditingController(text: widget.state.cloudSync.port.toString());
    _cloudTokenController = TextEditingController(text: widget.state.cloudSync.token);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newRoomController.dispose();
    _cloudHostController.dispose();
    _cloudPortController.dispose();
    _cloudTokenController.dispose();
    super.dispose();
  }

  void _showExitTerminalDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: const Color(0xFF261C14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD86A38), width: 1.2),
        ),
        title: const Row(
          children: [
            Icon(Icons.power_settings_new_rounded, color: Color(0xFFD86A38), size: 22),
            SizedBox(width: 8),
            Text('退出智慧终端？', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '智慧终端日常处于专机锁定防误触状态（系统返回键已禁用）。\n\n确认要退出中控程序，返回手机系统桌面吗？',
          style: TextStyle(color: Color(0xFFCEBAAA), fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dlgContext);
              Navigator.pop(context);
              const platform = MethodChannel('com.smarthome.terminal/hardware');
              try {
                await platform.invokeMethod('exitTerminal');
              } catch (_) {
                SystemNavigator.pop();
              }
            },
            child: const Text('确认退出', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: widget.state.useWarmHomeBackground
            ? const Color(0xF21F1710)
            : const Color(0xFF131824).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: widget.state.useWarmHomeBackground
              ? TerminalTheme.warmCardBorder
              : TerminalTheme.glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 30,
            spreadRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条与标题栏
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '智慧终端 · 房间与设备工程设置',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '支持多朝向卧室划分、电器归属重设与背景壁纸切换',
                    style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),

              // 设为默认桌面按钮（彻底杜绝按Home键切出系统）
              GestureDetector(
                onTap: () async {
                  const platform = MethodChannel('com.smarthome.terminal/hardware');
                  try {
                    await platform.invokeMethod('openHomeSettings');
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请前往手机系统设置 -> 默认应用 -> 桌面，选择【智慧家庭终端】')),
                      );
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x330984E3),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x6674B9FF)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_work_rounded, size: 14, color: Color(0xFF74B9FF)),
                      SizedBox(width: 4),
                      Text(
                        '设为默认桌面',
                        style: TextStyle(color: Color(0xFF74B9FF), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 退出终端按钮 (带安全防误触确认弹窗)
              GestureDetector(
                onTap: () => _showExitTerminalDialog(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x33E74C3C),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x66E74C3C)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.power_settings_new_rounded, size: 14, color: Color(0xFFFF7675)),
                      SizedBox(width: 4),
                      Text(
                        '退出终端',
                        style: TextStyle(color: Color(0xFFFF7675), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // 温馨背景壁纸开关
              GestureDetector(
                onTap: () {
                  widget.state.toggleBackgroundTheme();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.state.useWarmHomeBackground
                        ? TerminalTheme.amberPrimary.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.state.useWarmHomeBackground
                          ? TerminalTheme.amberPrimary
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.state.useWarmHomeBackground
                            ? Icons.home_rounded
                            : Icons.nightlight_round,
                        size: 14,
                        color: widget.state.useWarmHomeBackground
                            ? TerminalTheme.amberPrimary
                            : TerminalTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.state.useWarmHomeBackground ? '家庭实景背景' : '极简深空黑',
                        style: TextStyle(
                          color: widget.state.useWarmHomeBackground
                              ? TerminalTheme.amberPrimary
                              : TerminalTheme.textSecondary,
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
          const SizedBox(height: 12),

          // 选项卡：【设备清单与分配】与【房间朝向管理】
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF6C5CE7),
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: TerminalTheme.textSecondary,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: '📱 全屋电器与房间归属'),
                Tab(text: '🏠 房间朝向与自定义增删'),
                Tab(text: '☁️ 云端同步与远程部署'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 选项卡内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeviceListTab(),
                _buildRoomManagerTab(),
                _buildCloudSyncTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 选项卡 1：设备清单与分配 ---
  Widget _buildDeviceListTab() {
    final devices = widget.state.allDevices;
    return ListView.separated(
      itemCount: devices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = devices[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2130).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TerminalTheme.amberPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d.id,
                  style: const TextStyle(
                    color: TerminalTheme.amberPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '当前房间: ${d.room}  ·  MQTT: sh/h01/${d.id}/cmd',
                      style: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              GestureDetector(
                onTap: () => _editDeviceDialog(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.6)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, color: Color(0xFFA29BFE), size: 12),
                      SizedBox(width: 4),
                      Text(
                        '更改配置',
                        style: TextStyle(color: Color(0xFFA29BFE), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 选项卡 2：房间朝向与自定义增删 ---
  Widget _buildRoomManagerTab() {
    final manageableRooms = widget.state.rooms.where((r) => r != '全部').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 新增房间输入框与快捷朝向标签
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2130).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '添加新房间 / 区分朝向多卧室',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newRoomController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: '输入自定义房间 (例如: 次卧(西)、长辈房、阳光阳台)',
                          hintStyle: const TextStyle(color: TerminalTheme.textMuted, fontSize: 12),
                          filled: true,
                          fillColor: Colors.black26,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        final name = _newRoomController.text.trim();
                        if (name.isNotEmpty) {
                          widget.state.addRoom(name);
                          _newRoomController.clear();
                          setState(() {});
                        }
                      },
                      child: const Text('添加房间', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 快捷朝向预设
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    '主卧(南)',
                    '次卧(南)',
                    '次卧(北)',
                    '次卧(东)',
                    '长辈房',
                    '儿童房',
                    '书房(东)',
                    '阳光房',
                    '主卫',
                    '客卫',
                  ].map((preset) {
                    return GestureDetector(
                      onTap: () {
                        widget.state.addRoom(preset);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          '+ $preset',
                          style: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 现有房间列表
          const Text(
            '现有房间列表 (点击红色删除按钮可移除自定义房间):',
            style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: manageableRooms.map((rm) {
              final isDefault = rm == '客厅';
              final count = widget.state.allDevices.where((d) => d.room == rm).length;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2130),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rm,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '($count)',
                      style: const TextStyle(color: TerminalTheme.amberPrimary, fontSize: 11),
                    ),
                    if (!isDefault) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          widget.state.removeRoom(rm);
                          setState(() {});
                        },
                        child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // --- 选项卡 3：云端公网双向同步与远程部署 ---
  Widget _buildCloudSyncTab() {
    final sync = widget.state.cloudSync;
    final isOnline = sync.status == CloudConnectionStatus.connected;
    final isSyncing = sync.status == CloudConnectionStatus.syncing;
    final isConnecting = sync.status == CloudConnectionStatus.connecting;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态看板
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOnline
                  ? const Color(0x1F2ECC71)
                  : (isConnecting || isSyncing ? const Color(0x1FF39C12) : const Color(0x15FFFFFF)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOnline
                    ? const Color(0x662ECC71)
                    : (isConnecting || isSyncing ? const Color(0x66F39C12) : Colors.white24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isOnline
                      ? Icons.cloud_done_rounded
                      : (isConnecting || isSyncing ? Icons.cloud_sync_rounded : Icons.cloud_off_rounded),
                  color: isOnline
                      ? const Color(0xFF2ECC71)
                      : (isConnecting || isSyncing ? const Color(0xFFF39C12) : TerminalTheme.textSecondary),
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isOnline ? '云端已就绪 · 双向长连接活跃' : (isConnecting ? '正在连接云端中枢...' : (isSyncing ? '数据同步中...' : '云端离线 · 本地兜底模式')),
                            style: TextStyle(
                              color: isOnline ? const Color(0xFF2ECC71) : (isConnecting || isSyncing ? const Color(0xFFF39C12) : Colors.white),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (isOnline)
                            Text(
                              'RTT: ${sync.latencyMs}ms',
                              style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '当前节点：${sync.host}:${sync.port} · 通信信道：WebSocket (Duplex) / HTTP REST · 租户：${sync.homeId}',
                        style: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 云端地址与凭证配置
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF161E2E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '⚙️ 公网云端节点配置 (Cloud Server Endpoint)',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  '支持本地开发电脑调试（127.0.0.1 或局域网 IP）及公网云服务器（阿里云/腾讯云/AWS 域名或公网 IP）无缝切换',
                  style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _cloudHostController,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: '云端服务器 IP / 域名',
                          labelStyle: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                          hintText: '如 127.0.0.1 或 cloud.mysmarthome.com',
                          hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0F141F),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _cloudPortController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: '端口',
                          labelStyle: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                          hintText: '8000',
                          filled: true,
                          fillColor: const Color(0xFF0F141F),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _cloudTokenController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: '云端访问 Token 密钥 (Auth Token)',
                          labelStyle: const TextStyle(color: TerminalTheme.textSecondary, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF0F141F),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C5CE7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: () {
                        final host = _cloudHostController.text.trim();
                        final port = int.tryParse(_cloudPortController.text.trim()) ?? 8000;
                        sync.token = _cloudTokenController.text.trim();
                        sync.connect(newHost: host, newPort: port);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已重新发起连接到云端 -> $host:$port')),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: const Text('连接云端', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 同步控制与架构说明
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalTheme.amberPrimary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    widget.state.syncAllToCloud();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已触发全屋电器与房间全量镜像上云！')),
                    );
                    setState(() {});
                  },
                  icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                  label: const Text('全量镜像同步到云端', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 架构原理提示
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white10),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: TerminalTheme.amberPrimary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '第一性原理工程规范：本系统抛弃了受限于同一个 Wi-Fi 路由器的 UDP 广播方案，采用纯公网可路由的标准全双工 WebSocket 长连接与 REST 接口。终端出站直连云端自动穿透家庭 NAT，即便将云端代码直接部署到公网 VPS（阿里云/腾讯云），终端亦只需填入对应公网 IP 或域名，即可瞬时实现异地数据同步与控制，100% 具备工业级云端迁移能力。',
                    style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 弹窗：编辑单个设备 ---
  void _editDeviceDialog(SmartDevice d) {
    final nameCtrl = TextEditingController(text: d.name);
    String currentRoom = d.room;
    final availableRooms = widget.state.rooms.where((r) => r != '全部').toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2232),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '编辑设备 [${d.id}]',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('电器显示名称:', style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.black26,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    const Text('重新分配归属房间 (支持多卧室朝向):', style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: availableRooms.map((rm) {
                        final sel = rm == currentRoom;
                        return GestureDetector(
                          onTap: () => setDlgState(() => currentRoom = rm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF6C5CE7) : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: sel ? const Color(0xFFA29BFE) : Colors.transparent,
                              ),
                            ),
                            child: Text(
                              rm,
                              style: TextStyle(
                                color: sel ? Colors.white : TerminalTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: TerminalTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalTheme.amberPrimary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    widget.state.updateDevice(
                      d.id,
                      newName: nameCtrl.text,
                      newRoom: currentRoom,
                    );
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  child: const Text('保存修改', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
