import 'dart:convert';

class SocketData {
  final String id;               // Unique socket ID
  final double current;          // current reading from ESP32
  final double tripThreshold;    // max allowed current
  final bool tripState;          // if socket tripped due to overload
  final bool relayState;         // ON/OFF (mapped from socket_status)
  final double voltage;          // voltage_reading
  final double power;            // power_reading or calculated
  final double energy;           // cumulative energy in kWh
  final String? action;          // optional action/status from ESP32
  final int? resetSignal;        // optional reset command
  final String? timestamp;       // last update timestamp

  // Local usage tracking
  final Map<String, double> dailyUsage;   // e.g., {"2026-02-24": 2.5 kWh}
  final Map<String, double> weeklyUsage;  // e.g., {"Week9-2026": 15.0 kWh}

  /// Calculate power if ESP32 does not send it
  double get calculatedPower => voltage * current;

  SocketData({
    required this.id,
    required this.current,
    required this.tripThreshold,
    required this.tripState,
    required this.relayState,
    required this.voltage,
    required this.power,
    required this.energy,
    this.action,
    this.resetSignal,
    this.timestamp,
    Map<String, double>? dailyUsage,
    Map<String, double>? weeklyUsage,
  })  : dailyUsage = dailyUsage ?? {},
        weeklyUsage = weeklyUsage ?? {};

  /// Parse JSON from ESP32 or Firebase
  factory SocketData.fromJson(String id, Map<String, dynamic> json) {
    return SocketData(
      id: id,
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      tripThreshold: (json['tripThreshold'] as num?)?.toDouble() ?? 0.0,
      tripState: json['socket_tripped'] == true || json['tripState'] == true,
      relayState: (json['socket_status'] == 1) || (json['relayState'] == true),
      voltage: (json['voltage'] as num?)?.toDouble() ?? 0.0,
      power: (json['power'] as num?)?.toDouble() ??
          ((json['voltage'] as num?)?.toDouble() ?? 0.0) *
              ((json['current'] as num?)?.toDouble() ?? 0.0),
      energy: (json['energy'] as num?)?.toDouble() ?? 0.0,
      action: json['action'] as String?,
      resetSignal: json['reset_signal'] as int?,
      timestamp: json['timestamp'] as String?,
      dailyUsage: (json['dailyUsage'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ) ??
          {},
      weeklyUsage: (json['weeklyUsage'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      ) ??
          {},
    );
  }

  /// Convert back to JSON for Firebase or WebSocket
  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'tripThreshold': tripThreshold,
      'socket_tripped': tripState,
      'socket_status': relayState ? 1 : 0,
      'voltage_reading': voltage,
      'power_reading': power,
      'energy': energy,
      'action': action,
      'reset_signal': resetSignal,
      'timestamp': timestamp,
      'dailyUsage': dailyUsage,
      'weeklyUsage': weeklyUsage,
    };
  }

  /// Create a copy with updated fields
  SocketData copyWith({
    String? id,
    double? current,
    double? tripThreshold,
    bool? tripState,
    bool? relayState,
    double? voltage,
    double? power,
    double? energy,
    String? action,
    int? resetSignal,
    String? timestamp,
    Map<String, double>? dailyUsage,
    Map<String, double>? weeklyUsage,
  }) {
    return SocketData(
      id: id ?? this.id,
      current: current ?? this.current,
      tripThreshold: tripThreshold ?? this.tripThreshold,
      tripState: tripState ?? this.tripState,
      relayState: relayState ?? this.relayState,
      voltage: voltage ?? this.voltage,
      power: power ?? this.power,
      energy: energy ?? this.energy,
      action: action ?? this.action,
      resetSignal: resetSignal ?? this.resetSignal,
      timestamp: timestamp ?? this.timestamp,
      dailyUsage: dailyUsage ?? Map<String, double>.from(this.dailyUsage),
      weeklyUsage: weeklyUsage ?? Map<String, double>.from(this.weeklyUsage),
    );
  }
}

/// Command to send to ESP32
class SocketCommand {
  final String command;           // "toggle", "reset", "update", "setRelay"
  final bool? relayState;         // ON/OFF
  final double? tripThreshold;    // optional max current
  final double? voltage;          // optional override
  final double? power;            // optional override
  final double? energy;           // optional energy update
  final int? resetSignal;         // trigger reset
  final String? timestamp;        // optional timestamp

  SocketCommand({
    required this.command,
    this.relayState,
    this.tripThreshold,
    this.voltage,
    this.power,
    this.energy,
    this.resetSignal,
    this.timestamp,
  });

  /// Convert command to JSON for ESP32/Firebase
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {'command': command};
    if (relayState != null) json['socket_status'] = relayState! ? 1 : 0;
    if (tripThreshold != null) json['tripThreshold'] = tripThreshold;
    if (voltage != null) json['voltage_reading'] = voltage;
    if (power != null) json['power_reading'] = power;
    if (energy != null) json['energy'] = energy;
    if (resetSignal != null) json['reset_signal'] = resetSignal;
    if (timestamp != null) json['timestamp'] = timestamp;
    return json;
  }
}