import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

enum CloudConnectionStatus {
  disconnected,
  connecting,
  connected,
  syncing,
  error,
}

/// 工业级云端全双工数据同步服务 (CloudSyncService)
///
/// 架构原则：
/// 1. 云原生标准公网协议：基于标准 WebSocket / HTTP REST，杜绝不可路由的局域网单播/组播依赖；
/// 2. 无论云端部署在开发者电脑（Localhost / 局域网测试）还是公网 VPS（阿里云/腾讯云/AWS），
///    终端只需切换目标 Host 与 Token，底层协议与行为 100% 一致；
/// 3. 全双工长连接通道：主动出站建立 WebSocket，自动穿透各类家用 NAT 路由器与防火墙；
/// 4. 双向增量同步：终端操作实时上报云端，云端远程控制或 AI 联动指令即时下发推送到屏。
class CloudSyncService {
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  // 云端配置 (可动态配置)
  String host = '192.168.1.12'; // 默认电脑端服务局域网 IP (亦可设为 127.0.0.1 或公网 VPS 域名)
  int port = 8000;
  String homeId = 'h01';
  String token = 'smarthome_cloud_secret_token_2026';

  CloudConnectionStatus status = CloudConnectionStatus.disconnected;
  String? lastError;
  DateTime? lastSyncTime;
  int latencyMs = 0;

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _intentionalDisconnect = false;
  DateTime? _lastPingTime;

  // 状态变更监听回调
  void Function(CloudConnectionStatus status)? onStatusChanged;
  void Function(String deviceId, Map<String, dynamic> state)? onRemoteStateReceived;
  void Function(List<Map<String, dynamic>> devices, List<String> rooms)? onSnapshotReceived;

  /// 初始化并建立连接
  Future<void> connect({String? newHost, int? newPort}) {
    if (newHost != null) host = newHost.trim();
    if (newPort != null) port = newPort;
    _intentionalDisconnect = false;
    _cancelReconnect();
    return _doConnect();
  }

  Future<void> _doConnect() async {
    _updateStatus(CloudConnectionStatus.connecting);
    final wsUrl = 'ws://$host:$port/ws/terminal?client_id=terminal_screen&home_id=$homeId';

    try {
      if (kDebugMode) {
        print('[CloudSync] Connecting to Cloud Hub: $wsUrl');
      }
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 6));
      _updateStatus(CloudConnectionStatus.connected);
      lastError = null;

      // 监听云端消息推送
      _socket!.listen(
        _handleIncomingData,
        onDone: _onDisconnected,
        onError: (err) {
          lastError = err.toString();
          _onDisconnected();
        },
        cancelOnError: true,
      );

      // 启动心跳守护
      _startHeartbeat();
    } catch (e) {
      lastError = e.toString();
      _updateStatus(CloudConnectionStatus.error);
      _scheduleReconnect();
    }
  }

  void _handleIncomingData(dynamic message) {
    try {
      final jsonMap = jsonDecode(message as String) as Map<String, dynamic>;
      final type = jsonMap['type'] as String?;
      final payload = jsonMap['payload'] as Map<String, dynamic>? ?? {};

      if (type == 'PONG') {
        if (_lastPingTime != null) {
          latencyMs = DateTime.now().difference(_lastPingTime!).inMilliseconds;
        }
      } else if (type == 'SNAPSHOT_SYNC') {
        // 收到云端全量数据快照
        final rawDevices = (payload['devices'] as List<dynamic>? ?? [])
            .map((e) => e as Map<String, dynamic>)
            .toList();
        final rawRooms = (payload['rooms'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();
        lastSyncTime = DateTime.now();
        onSnapshotReceived?.call(rawDevices, rawRooms);
      } else if (type == 'STATE_UPDATE') {
        // 收到云端单个设备增量状态更新
        final devId = payload['device_id'] as String?;
        final state = payload['state'] as Map<String, dynamic>? ?? {};
        if (devId != null) {
          lastSyncTime = DateTime.now();
          onRemoteStateReceived?.call(devId, state);
        }
      } else if (type == 'SYNC_ACK') {
        lastSyncTime = DateTime.now();
        _updateStatus(CloudConnectionStatus.connected);
      }
    } catch (e) {
      if (kDebugMode) {
        print('[CloudSync] Failed to parse incoming packet: $e');
      }
    }
  }

  /// 终端向云端上报设备状态变更
  void sendStateUpdate(String deviceId, Map<String, dynamic> stateDelta) {
    if (_socket == null || status != CloudConnectionStatus.connected) return;

    final envelope = {
      'type': 'STATE_UPDATE',
      'payload': {
        'device_id': deviceId,
        'state': stateDelta,
        'src': 'terminal_screen',
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    };

    try {
      _socket!.add(jsonEncode(envelope));
    } catch (e) {
      if (kDebugMode) {
        print('[CloudSync] Send state update failed: $e');
      }
    }
  }

  /// 终端全量上传本地配置到云端（如初次对接或添加了新设备/房间）
  void uploadAllToCloud(List<Map<String, dynamic>> devices, List<String> rooms) {
    if (_socket == null || status != CloudConnectionStatus.connected) return;
    _updateStatus(CloudConnectionStatus.syncing);

    final envelope = {
      'type': 'SYNC_UPLOAD',
      'payload': {
        'devices': devices,
        'rooms': rooms,
      },
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    };

    try {
      _socket!.add(jsonEncode(envelope));
    } catch (e) {
      _updateStatus(CloudConnectionStatus.error);
    }
  }

  /// 主动断开连接
  void disconnect() {
    _intentionalDisconnect = true;
    _stopHeartbeat();
    _cancelReconnect();
    _socket?.close();
    _socket = null;
    _updateStatus(CloudConnectionStatus.disconnected);
  }

  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_socket != null && status == CloudConnectionStatus.connected) {
        _lastPingTime = DateTime.now();
        final ping = {
          'type': 'PING',
          'payload': {},
          'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
        };
        try {
          _socket!.add(jsonEncode(ping));
        } catch (_) {}
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onDisconnected() {
    _stopHeartbeat();
    _socket = null;
    if (!_intentionalDisconnect) {
      _updateStatus(CloudConnectionStatus.disconnected);
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _cancelReconnect();
    if (_intentionalDisconnect) return;
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _doConnect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _updateStatus(CloudConnectionStatus s) {
    status = s;
    onStatusChanged?.call(status);
  }
}
