import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/cloud_device.dart';

enum AppCloudStatus {
  connecting,
  connected,
  disconnected,
  error,
}

class MiCloudService extends ChangeNotifier {
  static final MiCloudService _instance = MiCloudService._internal();
  factory MiCloudService() => _instance;
  MiCloudService._internal();

  String host = '192.168.1.12';
  int port = 8000;
  String homeId = 'h01';

  AppCloudStatus connectionStatus = AppCloudStatus.disconnected;
  String? errorMessage;
  bool isLoadingInitial = true;
  int latencyMs = 0;
  int activeClients = 1;

  List<CloudDevice> devices = [];
  List<String> rooms = [];
  final Set<String> pendingDeviceIds = {};
  final List<String> eventLogs = [];

  WebSocket? _socket;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  DateTime? _lastPingTime;
  bool _disposed = false;

  String get httpBase => 'http://$host:$port';
  String get wsUrl => 'ws://$host:$port/ws/terminal?client_id=mihome_mobile_app&home_id=$homeId';

  int get activeDeviceCount => devices.where((d) => d.isActive).length;

  int get estimatedPowerWatts {
    double total = 18;
    for (final d in devices) {
      total += d.powerWatts;
    }
    return total.round();
  }

  Future<void> initialize() async {
    await refreshAll();
    connectWebSocket();
  }

  Future<void> configureEndpoint(String newHost, int newPort) async {
    host = newHost.trim();
    port = newPort;
    await _closeSocket();
    isLoadingInitial = true;
    errorMessage = null;
    notifyListeners();
    await refreshAll();
    connectWebSocket();
  }

  Future<void> refreshAll() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final devJson = await _getJson(client, '$httpBase/api/v1/devices') as List<dynamic>;
      final roomJson = await _getJson(client, '$httpBase/api/v1/rooms') as List<dynamic>;
      final infoJson = await _getJson(client, '$httpBase/api/v1/cloud/info') as Map<String, dynamic>;

      devices = devJson
          .map((e) => CloudDevice.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      rooms = roomJson.map((e) => e.toString()).toList();
      activeClients = (infoJson['active_clients'] as num?)?.toInt() ?? activeClients;
      errorMessage = null;
    } catch (e) {
      errorMessage = '云端请求失败: $e';
    } finally {
      isLoadingInitial = false;
      client.close();
      notifyListeners();
    }
  }

  Future<dynamic> _getJson(HttpClient client, String url) async {
    final req = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
    final resp = await req.close().timeout(const Duration(seconds: 5));
    final body = await resp.transform(utf8.decoder).join();
    if (resp.statusCode != 200) {
      throw HttpException('HTTP ${resp.statusCode}: $body');
    }
    return jsonDecode(body);
  }

  Future<String?> updateDeviceState(String deviceId, Map<String, dynamic> delta) async {
    pendingDeviceIds.add(deviceId);
    notifyListeners();

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client
          .postUrl(Uri.parse('$httpBase/api/v1/devices/${Uri.encodeComponent(deviceId)}/state'))
          .timeout(const Duration(seconds: 5));
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(jsonEncode({
        'device_id': deviceId,
        'state': delta,
        'src': 'app',
      })));

      final resp = await req.close().timeout(const Duration(seconds: 5));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
      }
      final updated = CloudDevice.fromJson(Map<String, dynamic>.from(jsonDecode(body) as Map));
      _replaceDevice(updated);
      _appendLog('下发 $deviceId -> ${jsonEncode(delta)}');
      errorMessage = null;
      return null;
    } catch (e) {
      return '控制下发失败: $e';
    } finally {
      pendingDeviceIds.remove(deviceId);
      client.close();
      notifyListeners();
    }
  }

  Future<String?> triggerScene(String sceneId) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client
          .postUrl(Uri.parse('$httpBase/api/v1/scenes/${Uri.encodeComponent(sceneId)}/trigger?src=app'))
          .timeout(const Duration(seconds: 5));
      final resp = await req.close().timeout(const Duration(seconds: 5));
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}');
      }
      final data = Map<String, dynamic>.from(jsonDecode(body) as Map);
      final rawDevs = data['devices'] as List<dynamic>? ?? [];
      if (rawDevs.isNotEmpty) {
        devices = rawDevs
            .map((e) => CloudDevice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      _appendLog('触发场景「${data['scene_name']}」· ${data['updated_count']}台响应');
      notifyListeners();
      return null;
    } catch (e) {
      return '场景执行失败: $e';
    } finally {
      client.close();
    }
  }

  Future<List<Map<String, dynamic>>> fetchTelemetry(String deviceId) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final list = await _getJson(
        client,
        '$httpBase/api/v1/telemetry/${Uri.encodeComponent(deviceId)}?limit=20',
      ) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    } finally {
      client.close();
    }
  }

  Future<void> connectWebSocket() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    connectionStatus = AppCloudStatus.connecting;
    notifyListeners();

    try {
      _socket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 6));
      connectionStatus = AppCloudStatus.connected;
      errorMessage = null;
      _appendLog('WebSocket 长连接已建立');
      notifyListeners();

      _socket!.listen(
        _handleWsMessage,
        onDone: _handleWsClosed,
        onError: (err) {
          connectionStatus = AppCloudStatus.error;
          errorMessage = '信道异常: $err';
          _handleWsClosed();
        },
        cancelOnError: true,
      );

      _heartbeatTimer?.cancel();
      _sendPing();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 8), (_) => _sendPing());
    } catch (e) {
      connectionStatus = AppCloudStatus.error;
      errorMessage = '无法连接云端 ($host:$port): $e';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _sendPing() {
    if (_socket == null || _socket!.readyState != WebSocket.open) return;
    _lastPingTime = DateTime.now();
    _socket!.add(jsonEncode({'type': 'PING', 'payload': {}}));
  }

  void _handleWsMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type']?.toString();
      final payload = Map<String, dynamic>.from(msg['payload'] as Map? ?? {});

      if (type == 'PONG') {
        if (_lastPingTime != null) {
          latencyMs = DateTime.now().difference(_lastPingTime!).inMilliseconds.clamp(1, 9999);
          notifyListeners();
        }
        return;
      }

      if (type == 'STATE_UPDATE') {
        final devId = payload['device_id']?.toString();
        final newState = Map<String, dynamic>.from(payload['state'] as Map? ?? {});
        final ts = (payload['updated_at'] is num)
            ? (payload['updated_at'] as num).toDouble()
            : DateTime.now().millisecondsSinceEpoch / 1000.0;
        final src = payload['src']?.toString() ?? 'cloud';
        if (devId != null) {
          final idx = devices.indexWhere((d) => d.id == devId);
          if (idx != -1) {
            devices[idx] = devices[idx].copyWith(state: newState, updatedAt: ts);
            _appendLog('同步 $devId <- $src');
            notifyListeners();
          }
        }
      } else if (type == 'SNAPSHOT_SYNC') {
        final rawDevs = payload['devices'] as List<dynamic>? ?? [];
        final rawRooms = payload['rooms'] as List<dynamic>? ?? [];
        if (rawDevs.isNotEmpty) {
          devices = rawDevs
              .map((e) => CloudDevice.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        if (rawRooms.isNotEmpty) {
          rooms = rawRooms.map((e) => e.toString()).toList();
        }
        _appendLog('云端全量快照同步 (${devices.length} 台设备)');
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleWsClosed() {
    _heartbeatTimer?.cancel();
    if (_disposed) return;
    if (connectionStatus != AppCloudStatus.error) {
      connectionStatus = AppCloudStatus.disconnected;
    }
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), () {
      if (!_disposed) connectWebSocket();
    });
  }

  Future<void> _closeSocket() async {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void _replaceDevice(CloudDevice updated) {
    final idx = devices.indexWhere((d) => d.id == updated.id);
    if (idx != -1) {
      devices[idx] = updated;
    } else {
      devices.add(updated);
    }
  }

  void _appendLog(String line) {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final ss = now.second.toString().padLeft(2, '0');
    eventLogs.insert(0, '[$hh:$mm:$ss] $line');
    if (eventLogs.length > 40) {
      eventLogs.removeRange(40, eventLogs.length);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _closeSocket();
    super.dispose();
  }
}
