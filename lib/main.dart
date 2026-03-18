import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'LocalDatabase.dart';
import 'firebase_options.dart';
import 'loginPage.dart';

// ---------------------------
// Color Palette
// ---------------------------
const Color darkBg = Color(0xFF0f172a);
const Color cardBg = Color(0xFF1f2937);
const Color borderColor = Color(0xFF374151);
const Color primaryAccent = Color(0xFF06b6d4);
const Color successGreen = Color(0xFF10b981);
const Color warningAmber = Color(0xFFd97706);
const Color dangerRed = Color(0xFFef4444);
const Color textPrimary = Color(0xFFe5e7eb);
const Color textSecondary = Color(0xFF9ca3af);

// ---------------------------
// Firebase Realtime DB
// ---------------------------
late final DatabaseReference db;

// ---------------------------
// Flutter App Main
// ---------------------------
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  db = FirebaseDatabase.instance.ref();

  runApp(const IntelligentSocketApp());
}

// ---------------------------
// Firebase Helpers
// ---------------------------
Future<Map<String, dynamic>?> getSocketFromFirebase(int id) async {
  final snapshot = await db.child("sockets/$id").get();
  if (snapshot.exists) {
    return Map<String, dynamic>.from(snapshot.value as Map);
  }
  return null;
}

Future<void> turnOnSocket(int id) async {
  await db.child("sockets/$id/state").set(true);
}

void listenToSockets(Function(Map<String, dynamic>) onUpdate) {
  db.child("sockets").onValue.listen((event) {
    if (event.snapshot.exists) {
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      onUpdate(data);
    }
  });
}

Future<void> syncAllSockets() async {
  final sockets = await LocalDatabase.getAllSockets();
  for (var socket in sockets) {
    await db.child("sockets/${socket['id']}").set(socket);
  }
}

// ---------------------------
// Flutter App
// ---------------------------
class IntelligentSocketApp extends StatefulWidget {
  const IntelligentSocketApp({Key? key}) : super(key: key);

  @override
  State<IntelligentSocketApp> createState() => _IntelligentSocketAppState();
}

class _IntelligentSocketAppState extends State<IntelligentSocketApp> {
  bool _isDarkMode = false;
  Map<String, dynamic> socketData = {};

  @override
  void initState() {
    super.initState();
    // Listen for live updates from Firebase
    listenToSockets((data) {
      setState(() => socketData = data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: _buildDarkTheme(),
      themeMode: _isDarkMode ? ThemeMode.light : ThemeMode.dark,

      // ----------------------
      // Use your LoginPage here
      // ----------------------
      home: LoginPage(
        isDarkMode: _isDarkMode,
        onThemeChanged: (isLightMode) {
          setState(() => _isDarkMode = isLightMode);
        },

      ),
    );
  }

  void toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primaryAccent,
        secondary: primaryAccent,
        surface: cardBg,
        error: dangerRed,
        onSurface: textPrimary,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
        bodySmall: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
      ),
    );
  }
}

// ---------------------------
// Socket Dashboard
// ---------------------------
class SocketDashboard extends StatelessWidget {
  final Map<String, dynamic> socketData;
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const SocketDashboard(this.socketData, this.isDarkMode, this.toggleTheme, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final socketStatus = socketData['socket_status'] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Socket Dashboard'),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: toggleTheme,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Socket is ${socketStatus ? "ON" : "OFF"}', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                await db.child('socket_status').set(!socketStatus);
              },
              child: const Text('Toggle Socket'),
            ),
            const SizedBox(height: 20),
            Text('Voltage: ${socketData['voltage_reading'] ?? 0.0} V'),
            Text('Current: ${socketData['current_reading'] ?? 0.0} A'),
            Text('Power: ${socketData['power_reading'] ?? 0.0} W'),
            Text('Energy: ${socketData['energy_consumed'] ?? 0.0} kWh'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: syncAllSockets,
              child: const Text('Sync Local DB to Firebase'),
            ),
          ],
        ),
      ),
    );
  }
}