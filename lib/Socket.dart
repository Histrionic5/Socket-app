import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Socket_data.dart';
import 'LocalDatabase.dart';
typedef SocketCallback = void Function(SocketData);

class Socket {
  // --- WebSocket fields ---
  late WebSocketChannel _channel;
  bool _isConnected = false;
  bool _isManuallyClosed = false;

  // --- Firebase fields ---
  FirebaseDatabase _db = FirebaseDatabase.instance;
  StreamSubscription<DatabaseEvent>? _firebaseSubscription;

  // --- Socket data ---
  SocketData? _socketData;
  SocketCallback? onDataChanged;

  final String wsUrl;       // WebSocket URL for ESP32
  final String firebasePath; // Firebase path, e.g., 'sockets/1'
  final int reconnectDelaySeconds;
  final int? socketId;      // Local DB socket ID

  Socket({
    required this.wsUrl,
    required this.firebasePath,
    this.onDataChanged,
    this.reconnectDelaySeconds = 3,
    this.socketId,
  });

  SocketData? get socketData => _socketData;
  bool get isConnected => _isConnected;

  // --- Connect both WebSocket & Firebase ---
  void connect() {
    _isManuallyClosed = false;
    _connectWebSocket();
    _connectFirebase();
  }

  // --- WebSocket connection ---
  void _connectWebSocket() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel.stream.listen(
            (message) async {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            final id = socketId?.toString() ?? "default";
            _socketData = SocketData.fromJson(id, data);
            _isConnected = true;

            // Merge local DB
            if (socketId != null) {
              final saved = await LocalDatabase.getSocketById(socketId!);
              if (saved != null) {
                _socketData = _socketData!.copyWith(
                  energy: (saved['energy'] as num?)?.toDouble() ?? _socketData!.energy,
                  dailyUsage: Map<String, double>.from(saved['dailyUsage'] ?? {}),
                  weeklyUsage: Map<String, double>.from(saved['weeklyUsage'] ?? {}),
                );
              }
            }

            if (_socketData != null && onDataChanged != null) onDataChanged!(_socketData!);
          } catch (_) {
            _isConnected = false;
          }
        },
        onError: (_) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isManuallyClosed) return;
    Future.delayed(Duration(seconds: reconnectDelaySeconds), () {
      if (!_isConnected) _connectWebSocket();
    });
  }

  // --- Firebase connection ---
  void _connectFirebase() {
    _firebaseSubscription = _db.ref(firebasePath).onValue.listen((event) async {
      final value = event.snapshot.value as Map<dynamic, dynamic>?;

      if (value == null) return;

      final firebaseData = Map<String, dynamic>.from(value);
      _socketData = SocketData.fromJson(socketId?.toString() ?? "default", firebaseData);

      // Merge local DB energy & usage
      if (socketId != null) {
        final saved = await LocalDatabase.getSocketById(socketId!);
        if (saved != null) {
          _socketData = _socketData!.copyWith(
            energy: (saved['energy'] as num?)?.toDouble() ?? _socketData!.energy,
            dailyUsage: Map<String, double>.from(saved['dailyUsage'] ?? {}),
            weeklyUsage: Map<String, double>.from(saved['weeklyUsage'] ?? {}),
          );
        }
      }

      if (_socketData != null && onDataChanged != null) onDataChanged!(_socketData!);
    });
  }

  // --- Send command (updates Firebase + WebSocket + local DB) ---
  Future<void> sendCommand(SocketCommand cmd) async {
    if (_socketData == null) return;

    // --- Update WebSocket ---
    if (_isConnected) _channel.sink.add(jsonEncode(cmd.toJson()));

    // --- Update SocketData ---
    bool? newRelay = cmd.relayState ?? _socketData!.relayState;
    double updatedEnergy = cmd.energy ?? _socketData!.energy ?? 0.0;
    double updatedThreshold = cmd.tripThreshold ?? _socketData!.tripThreshold;

    _socketData = _socketData!.copyWith(
      relayState: newRelay,
      energy: updatedEnergy,
      tripThreshold: updatedThreshold,
    );

    // --- Update Firebase ---
    await _db.ref(firebasePath).update({
      'relayState': newRelay,
      'energy': updatedEnergy,
      'tripThreshold': updatedThreshold,
    });

    // --- Update local DB ---
    if (socketId != null) {
      await LocalDatabase.updateSocketState(
        id: socketId!,
        power: _socketData!.power,
        energy: updatedEnergy,
        threshold: updatedThreshold,
        dailyUsage: _socketData!.dailyUsage,
        weeklyUsage: _socketData!.weeklyUsage,
      );
    }

    if (onDataChanged != null) onDataChanged!(_socketData!);
  }

  // --- Convenience ---
  Future<void> turnOn({double? energy}) => sendCommand(SocketCommand(command: "setRelay", relayState: true, energy: energy));
  Future<void> turnOff({double? energy}) => sendCommand(SocketCommand(command: "setRelay", relayState: false, energy: energy));

  // --- Disconnect ---
  void disconnect() {
    _isManuallyClosed = true;
    _channel.sink.close();
    _firebaseSubscription?.cancel();
    _isConnected = false;
  }
}