class SocketData {
  final double current;
  final double tripThreshold;
  final bool tripState;
  final bool? relayState; // ON/OFF
  final double? voltage;
  final double? power; // optional: comes from ESP32
  final double? energy; // optional: cumulative energy in kWh

  /// Always calculated from voltage × current if power not sent
  double get calculatedPower => (voltage ?? 0) * current;

  SocketData({
    required this.current,
    required this.tripThreshold,
    required this.tripState,
    this.relayState,
    this.voltage,
    this.power, // optional: keeps ESP32 value if sent
    this.energy, // optional: keeps stored cumulative energy
  });

  /// Parse JSON from ESP32
  factory SocketData.fromJson(Map<String, dynamic> json) {
    return SocketData(
      current: (json['current'] as num?)?.toDouble() ?? 0.0,
      tripThreshold: (json['tripThreshold'] as num?)?.toDouble() ?? 0.0,
      tripState: json['tripState'] == true,
      relayState: json['relayState'] == true,
      voltage: (json['voltage'] as num?)?.toDouble(),
      power: (json['power'] as num?)?.toDouble(),
      energy: (json['energy'] as num?)?.toDouble(),
    );
  }

  /// Convert back to JSON
  Map<String, dynamic> toJson() {
    return {
      'current': current,
      'tripThreshold': tripThreshold,
      'tripState': tripState,
      'relayState': relayState,
      'voltage': voltage,
      'power': power ?? calculatedPower, // use ESP32 value if available, else calculated
      'energy': energy ?? 0.0, // default to 0 if not set
    };
  }

  /// Create a copy with updated fields (useful for dashboard updates)
  SocketData copyWith({
    double? current,
    double? tripThreshold,
    bool? tripState,
    bool? relayState,
    double? voltage,
    double? power,
    double? energy,
  }) {
    return SocketData(
      current: current ?? this.current,
      tripThreshold: tripThreshold ?? this.tripThreshold,
      tripState: tripState ?? this.tripState,
      relayState: relayState ?? this.relayState,
      voltage: voltage ?? this.voltage,
      power: power ?? this.power,
      energy: energy ?? this.energy,
    );
  }
}

class SocketCommand {
  final String command;
  final String? relayState;      // "ON"/"OFF" or other
  final double? tripThreshold;   // optional threshold value
  final double? energy;          // optional energy update

  SocketCommand({
    required this.command,
    this.relayState,
    this.tripThreshold,
    this.energy,
  });

  /// Convert command to JSON to send to ESP32
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {'command': command};

    if (relayState != null) json['relayState'] = relayState;
    if (tripThreshold != null) json['tripThreshold'] = tripThreshold;
    if (energy != null) json['energy'] = energy;

    return json;
  }
}
