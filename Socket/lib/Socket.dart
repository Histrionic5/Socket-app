import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'Socket_data.dart';
import 'package:my_wife/LocalDatabase.dart';

typedef SocketCallback = void Function(SocketData);

class Socket {
  late WebSocketChannel _channel;
  bool _isConnected = false;
  SocketData? _socketData;

  // Getter for socket data
  SocketData? get socketData => _socketData;
  bool get isConnected => _isConnected;

  // Callback when data changes
  SocketCallback? onDataChanged;

  final String wsUrl;
  final int reconnectDelaySeconds;
  bool _isManuallyClosed = false;
  int? socketId; // Optional: link to local database socket ID

  Socket({
    required this.wsUrl,
    this.onDataChanged,
    this.reconnectDelaySeconds = 3,
    this.socketId,
  });

  /// Connect to ESP32 via WebSocket
  void connect() {
    _isManuallyClosed = false;
    _connectInternal();
  }

  void _connectInternal() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel.stream.listen(
            (message) async {
          try {
            final data = jsonDecode(message);
            _socketData = SocketData.fromJson(data);
            _isConnected = true;

            // If linked to DB, fetch saved energy and merge
            if (socketId != null) {
              final savedSocket = await LocalDatabase.getSocketById(socketId!);
              if (savedSocket != null) {
                double savedEnergy = (savedSocket['energy'] as num?)?.toDouble() ?? 0.0;
                _socketData = _socketData!.copyWith(energy: savedEnergy);
              }
            }

            if (_socketData != null && onDataChanged != null) {
              onDataChanged!(_socketData!);
            }
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
      if (!_isConnected) _connectInternal();
    });
  }

  /// Send a command to ESP32 and optionally update local DB
  void sendCommand(SocketCommand cmd) async {
    if (!_isConnected) return;

    _channel.sink.add(jsonEncode(cmd.toJson()));

    if (_socketData != null) {
      // Update local socketData including energy
      double updatedEnergy = cmd.energy ?? _socketData!.energy ?? 0.0;
      _socketData = _socketData!.copyWith(
        tripThreshold: cmd.tripThreshold ?? _socketData!.tripThreshold,
        relayState: cmd.relayState == "ON"
            ? true
            : cmd.relayState == "OFF"
            ? false
            : _socketData!.relayState,
        energy: updatedEnergy,
      );

      // Save to local DB if socketId is set
      await LocalDatabase.updateSocketState(
        id: socketId!,
        power: _socketData!.power,
        energy: (updatedEnergy ?? 0.0).toDouble(),
        threshold: _socketData!.tripThreshold,
      );


      if (onDataChanged != null) onDataChanged!(_socketData!);
    }
  }

  void turnOn({double? energy}) => sendCommand(SocketCommand(command: "setRelay", relayState: "ON", energy: energy));

  void turnOff({double? energy}) => sendCommand(SocketCommand(command: "setRelay", relayState: "OFF", energy: energy));

  void disconnect() {
    _isManuallyClosed = true;
    _channel.sink.close();
    _isConnected = false;
  }
}
