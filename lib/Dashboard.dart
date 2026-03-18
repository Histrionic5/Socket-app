import 'package:flutter/material.dart';
import 'Socket.dart';
import 'Socket_data.dart';
import 'main.dart';
import 'LocalDatabase.dart';
import 'Settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class DashboardPage extends StatefulWidget {
  final List<int> selectedSockets; // 1 or more socket IDs
  final String socketName; // name of the primary socket

  const DashboardPage({
    Key? key,
    required this.selectedSockets,
    required this.socketName,
  }) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late Socket _socket;

  // UI State
  bool _isConnected = false;
  double _current = 0.0;
  double _voltage = 0.0;
  double _powerDrawn = 0.0;
  double _tripThreshold = 0.0;
  bool _isTripped = false;
  bool _isSocketActive = false;

  double _thresholdValue = 0.0; // Slider & dial value
  final double _maxThreshold = 10.0; // Maximum 10A

  final String _wsUrl = 'ws://192.168.0.101:81';

  // Notifications
  late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  bool _notificationSound = true;
  bool _notificationVibration = true;

  // Theme state (to pass to SettingsPage)
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();

    _socket = Socket(
      wsUrl: _wsUrl,
      firebasePath: 'sockets/socket1',  // <- add this line
      onDataChanged: _onSocketDataChanged,
    );

    _socket.connect();

    _initNotifications();
    loadSocketStates();
  }

  // -------------------
  // Load initial state from DB
  // -------------------
  Future<void> loadSocketStates() async {
    if (widget.selectedSockets.isNotEmpty) {
      final state =
      await LocalDatabase.getSocketById(widget.selectedSockets[0]);
      if (state != null) {
        setState(() {
          _isSocketActive = state["power"] > 0;
          _thresholdValue = state["threshold"]?.toDouble() ?? 0.0;
        });
      }
    }
  }

  Future<void> _initNotifications() async {
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initSettings,
    );

  }


  void _sendNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'threshold_channel',
      'Current Threshold Alerts',
      channelDescription: 'Notifies when current exceeds threshold',
      importance: Importance.max,
      priority: Priority.high,
      playSound: _notificationSound,
      enableVibration: _notificationVibration,
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: _notificationSound,
      presentAlert: true,
      presentBadge: true,
    );

    final details =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: '⚠️ Threshold Exceeded',
      body:
      'Current ${_current.toStringAsFixed(2)} A exceeded threshold ${_thresholdValue.toStringAsFixed(2)} A',
      notificationDetails: details,
      payload: 'threshold_alert',
    );
  }

  void _onSocketDataChanged(SocketData socketData) {
    setState(() {
      _current = socketData.current;
      _voltage = socketData.voltage ?? 0.0;
      _powerDrawn = socketData.calculatedPower;
      _tripThreshold = socketData.tripThreshold;
      _isTripped = socketData.tripState;
      _isSocketActive = socketData.relayState ?? false;
      _isConnected = _socket.isConnected;

      _thresholdValue = _tripThreshold;
    });

    if (_current > _thresholdValue) {
      _sendNotification();
    }
  }

  void _toggleSocket() {
    if (_isSocketActive) {
      _socket.turnOff();
    } else {
      _socket.turnOn();
    }
    saveStateToSockets();
  }

  Future<void> saveStateToSockets() async {
    for (int id in widget.selectedSockets) {
      await LocalDatabase.updateSocketState(
        id: id,
        power: _isSocketActive ? 1.0 : 0.0,
        threshold: _thresholdValue,
      );
    }
  }

  // ---------------------------
  // DashboardPage _showSettings
  // ---------------------------
  void _showSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username') ?? '';

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No logged-in user found.")),
      );
      return;
    }

    // Fetch user info from database
    final user = await LocalDatabase.getUserByUsername(username);

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found.")),
      );
      return;
    }

    final userId = user["id"] as int;
    final userName = user["username"] as String? ?? "User";
    final email = user["email"] as String? ?? "";

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          userId: userId,
          username: userName,
          email: email,
          isDarkMode: _isDarkMode,
          onThemeChanged: (val) => setState(() => _isDarkMode = val),
          notificationSound: _notificationSound,
          notificationVibration: _notificationVibration,
          onSoundChanged: (val) => setState(() => _notificationSound = val),
          onVibrationChanged: (val) =>
              setState(() => _notificationVibration = val),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _socket.isConnected;

    String socketTitle = widget.selectedSockets.length > 1
        ? "All Sockets Selected"
        : widget.socketName;

    return Scaffold(
      appBar: AppBar(
        title: Text(socketTitle),
        actions: [
          Icon(Icons.circle,
              color: isConnected ? successGreen : dangerRed, size: 12),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.menu), onPressed: _showSettings),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildPowerGauge(),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricCard("Voltage", "${_voltage.toStringAsFixed(2)} V", Icons.bolt),
                _buildMetricCard("Current", "${_current.toStringAsFixed(2)} A", Icons.speed),
              ],
            ),
            const SizedBox(height: 20),
            _buildThresholdControl(),
            const SizedBox(height: 20),
            _buildControlPanel(),
            const SizedBox(height: 20),
            Text(
              widget.selectedSockets.length > 1
                  ? "Applying changes to ${widget.selectedSockets.length} sockets"
                  : "Editing only: ${widget.socketName}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------
  // Widgets
  // ----------------------
  Widget _buildPowerGauge() {
    return SizedBox(
      width: 250,
      height: 150,
      child: CustomPaint(
        painter: _PowerSemiCirclePainter(value: _powerDrawn),
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
      BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Icon(icon, color: primaryAccent),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: textSecondary, fontSize: 12)),
          Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration:
      BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          const Text("Socket Control",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Transform.scale(
            scale: 2.0,
            child: Switch(
              value: _isSocketActive,
              onChanged: (val) => _toggleSocket(),
              activeColor: primaryAccent,
            ),
          ),
          const SizedBox(height: 20),
          Text(_isSocketActive ? "STATUS: ACTIVE" : "STATUS: INACTIVE",
              style: TextStyle(
                  color: _isSocketActive ? successGreen : textSecondary)),
        ],
      ),
    );
  }

  Widget _buildThresholdControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Text("Current Threshold",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          GestureDetector(
            onPanUpdate: (details) {
              final box = context.findRenderObject() as RenderBox;
              final center = box.size.center(Offset.zero);
              final touchPosition = details.localPosition - center;
              double angle = atan2(touchPosition.dy, touchPosition.dx) + pi / 2;

              double newVal = (angle / (2 * pi) * _maxThreshold);
              if (newVal < 0) newVal += _maxThreshold;
              if (newVal > _maxThreshold) newVal = _maxThreshold;

              setState(() {
                _thresholdValue = newVal;
              });
            },
            onPanEnd: (_) => saveStateToSockets(),
            child: SizedBox(
              width: 150,
              height: 150,
              child: CustomPaint(
                painter:
                _InteractiveDialPainter(value: _thresholdValue, maxValue: _maxThreshold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Slider(
            value: _thresholdValue,
            min: 0,
            max: _maxThreshold,
            divisions: (_maxThreshold * 10).toInt(),
            label: _thresholdValue.toStringAsFixed(1),
            onChanged: (val) {
              setState(() => _thresholdValue = val);
              saveStateToSockets();
            },
            onChangeEnd: (val) => saveStateToSockets(),
            activeColor: primaryAccent,
            inactiveColor: borderColor,
          ),
        ],
      ),
    );
  }
}

/// -------------------
/// Power Semi-Circle Painter
/// -------------------
class _PowerSemiCirclePainter extends CustomPainter {
  final double value;

  _PowerSemiCirclePainter({required this.value});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final greenPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    final orangePaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    final redPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    final startAngle = pi;
    final sweepGreen = pi * (500 / 1500);
    final sweepOrange = pi * (500 / 1500);
    final sweepRed = pi * (500 / 1500);

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepGreen, false, greenPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepGreen, sweepOrange, false, orangePaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle + sweepGreen + sweepOrange, sweepRed, false, redPaint);

    final pointerAngle = pi + (pi * (value / 1500)).clamp(0.0, pi);
    final pointerEnd = Offset(center.dx + radius * 0.8 * cos(pointerAngle),
        center.dy + radius * 0.8 * sin(pointerAngle));

    canvas.drawLine(center, pointerEnd, Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);

    final textPainter = TextPainter(
      text: TextSpan(
        text: "${value.toStringAsFixed(1)} W",
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(center.dx - textPainter.width / 2, center.dy - radius * 0.6));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// -------------------
/// Threshold Dial Painter
/// -------------------
class _InteractiveDialPainter extends CustomPainter {
  final double value;
  final double maxValue;

  _InteractiveDialPainter({required this.value, required this.maxValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;

    final backgroundPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke;

    final foregroundPaint = Paint()
      ..color = primaryAccent
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pointerPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    final sweepAngle = (value / maxValue) * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      foregroundPaint,
    );

    final pointerAngle = sweepAngle - pi / 2;
    final pointerEnd = Offset(center.dx + radius * 0.8 * cos(pointerAngle),
        center.dy + radius * 0.8 * sin(pointerAngle));
    canvas.drawLine(center, pointerEnd, pointerPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: "${value.toStringAsFixed(1)} A",
        style: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
