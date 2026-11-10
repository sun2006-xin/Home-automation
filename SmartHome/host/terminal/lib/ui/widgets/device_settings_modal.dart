import 'package:flutter/material.dart';
import '../../core/terminal_state.dart';
import '../../core/device_model.dart';
import '../theme/terminal_theme.dart';

/// 设备与房间自主配置面板 (DeviceSettingsModal)
///
/// 功能：
/// 1. 查看与自定义电器的【显示名称】、【硬件ID】与【归属房间】；
/// 2. 预览该电器对应的 MQTT 通信契约主题；
/// 3. 一键切换“温馨家居背景”与“极简深空黑”。
class DeviceSettingsModal extends StatefulWidget {
  final TerminalState state;

  const DeviceSettingsModal({super.key, required this.state});

  static void show(BuildContext context, TerminalState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceSettingsModal(state: state),
    );
  }

  @override
  State<DeviceSettingsModal> createState() => _DeviceSettingsModalState();
}

class _DeviceSettingsModalState extends State<DeviceSettingsModal> {
  @override
  Widget build(BuildContext context) {
    final devices = widget.state.allDevices;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF141923).withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: TerminalTheme.borderSubtle, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖动条与标题
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '电器与房间自定义配置',
                    style: TextStyle(
                      color: TerminalTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '可自由修改名称、归属房间与硬件 ID，修改即刻生效',
                    style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
              // 背景切换按钮
              GestureDetector(
                onTap: () {
                  widget.state.toggleBackgroundTheme();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.state.useWarmHomeBackground
                        ? TerminalTheme.amberWarm.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.state.useWarmHomeBackground
                          ? TerminalTheme.amberWarm
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.state.useWarmHomeBackground
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        size: 16,
                        color: widget.state.useWarmHomeBackground
                            ? TerminalTheme.amberWarm
                            : TerminalTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.state.useWarmHomeBackground ? '温馨家居背景' : '深空黑底',
                        style: TextStyle(
                          color: widget.state.useWarmHomeBackground
                              ? TerminalTheme.amberWarm
                              : TerminalTheme.textSecondary,
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
          const SizedBox(height: 20),

          // 设备列表
          Expanded(
            child: ListView.separated(
              itemCount: devices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final d = devices[idx];
                return _buildDeviceItem(d);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceItem(SmartDevice d) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TerminalTheme.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TerminalTheme.borderSubtle),
      ),
      child: Row(
        children: [
          // 硬件 ID 徽章
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              d.id,
              style: const TextStyle(
                color: TerminalTheme.amberWarm,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 设备名称与房间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.name,
                  style: const TextStyle(
                    color: TerminalTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '归属房间: ${d.room}  ·  MQTT 主题: sh/h01/${d.id}/cmd',
                  style: const TextStyle(
                    color: TerminalTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // 编辑按钮
          GestureDetector(
            onTap: () => _editDeviceDialog(d),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: TerminalTheme.borderSubtle,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.edit_rounded, size: 14, color: TerminalTheme.textSecondary),
                  SizedBox(width: 4),
                  Text(
                    '编辑',
                    style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editDeviceDialog(SmartDevice d) {
    final nameCtrl = TextEditingController(text: d.name);
    String currentRoom = d.room;
    final availableRooms = ['客厅', '餐厅', '主卧', '厨房', '卫生间', '阳台'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1B2232),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                '编辑设备 [${d.id}]',
                style: const TextStyle(color: TerminalTheme.textPrimary, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('显示名称:', style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: TerminalTheme.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('归属房间:', style: TextStyle(color: TerminalTheme.textSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableRooms.map((rm) {
                      final sel = rm == currentRoom;
                      return GestureDetector(
                        onTap: () {
                          setDlgState(() => currentRoom = rm);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? TerminalTheme.purpleMode : Colors.white10,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            rm,
                            style: TextStyle(
                              color: sel ? Colors.white : TerminalTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消', style: TextStyle(color: TerminalTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalTheme.amberWarm,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
