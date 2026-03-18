import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:firebase_database/firebase_database.dart';
// Ensure this path is correct based on your folder structure
import 'Socket_data.dart';

final DatabaseReference firebaseDb = FirebaseDatabase.instance.ref();

class LocalDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app_v4.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // For offline login - stores hashed credentials after first online login
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT,
        passwordHash TEXT NOT NULL
      )
    ''');

    // Stores the latest state of each socket
    await db.execute('''
      CREATE TABLE sockets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        relayState INTEGER DEFAULT 0,
        tripState INTEGER DEFAULT 0,
        voltage REAL DEFAULT 0.0,
        current REAL DEFAULT 0.0,
        power REAL DEFAULT 0.0,
        energy REAL DEFAULT 0.0,
        tripThreshold REAL DEFAULT 0.0,
        dailyUsage TEXT DEFAULT '{}',
        weeklyUsage TEXT DEFAULT '{}',
        timestamp TEXT
      )
    ''');

    // Stores every individual reading for historical graphing
    await db.execute('''
      CREATE TABLE usage_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        socketId INTEGER,
        power REAL,
        voltage REAL,
        current REAL,
        energy REAL,
        timestamp INTEGER,
        FOREIGN KEY(socketId) REFERENCES sockets(id)
      )
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          email TEXT,
          passwordHash TEXT NOT NULL
        )
      ''');
    }
  }

  /// -------------------
  /// OFFLINE LOGIN
  /// -------------------

  static Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final res = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return res.isNotEmpty ? res.first : null;
  }

  /// -------------------
  /// SOCKET LIST (for Dashboard)
  /// -------------------

  static Future<int> insertSocket(String name) async {
    final db = await database;
    return await db.insert(
      'sockets',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getAllSockets() async {
    final db = await database;
    return await db.query('sockets', orderBy: 'id');
  }

  /// -------------------
  /// DATA PERSISTENCE
  /// -------------------
  /// -------------------
  /// MISSING METHODS (ADDED TO FIX COMPILATION)
  /// -------------------

  // Get socket by ID (used in Dashboard and Socket.dart)
  static Future<Map<String, dynamic>?> getSocketById(int id) async {
    final db = await database;
    final res = await db.query('sockets', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  // Update socket state (relay, threshold, energy, usage)
  static Future<void> updateSocketState({
    required int id,
    double? power,
    double? energy,
    double? threshold,
    Map<String, double>? dailyUsage,
    Map<String, double>? weeklyUsage,
  }) async {
    final db = await database;

    final Map<String, Object?> values = {};

    if (power != null) values['power'] = power;
    if (energy != null) values['energy'] = energy;
    if (threshold != null) values['tripThreshold'] = threshold;
    if (dailyUsage != null) values['dailyUsage'] = jsonEncode(dailyUsage);
    if (weeklyUsage != null) values['weeklyUsage'] = jsonEncode(weeklyUsage);

    if (values.isEmpty) return;

    values['timestamp'] = DateTime.now().toIso8601String();

    await db.update(
      'sockets',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Delete a socket completely
  static Future<void> deleteSocket(int id) async {
    final db = await database;
    await db.delete('sockets', where: 'id = ?', whereArgs: [id]);
    await db.delete('usage_logs', where: 'socketId = ?', whereArgs: [id]);
  }

  // Get user by ID (used in Settings)
  static Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  // Update username
  static Future<void> updateUsername(int id, String newName) async {
    final db = await database;
    await db.update('users', {'username': newName}, where: 'id = ?', whereArgs: [id]);
  }

  // Update email
  static Future<void> updateEmail(int id, String newEmail) async {
    final db = await database;
    await db.update('users', {'email': newEmail}, where: 'id = ?', whereArgs: [id]);
  }

  // Update password
  static Future<void> updatePassword(int id, String newPasswordHash) async {
    final db = await database;
    await db.update('users', {'passwordHash': newPasswordHash}, where: 'id = ?', whereArgs: [id]);
  }

  // Read fingerprint preference
  static Future<bool> getFingerprintPreference(int userId) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [userId]);

    if (res.isEmpty) return false;

    // Store fingerprint preference inside email field or separate?
    // I will store it inside email field as metadata if you want, but instead:
    final passwordHash = res.first['passwordHash'] as String? ?? '';
    return passwordHash.contains('FP_ENABLED');
  }

  static Future<void> deleteUser(int userId) async {
    final db = await database;

    // 1️⃣ Delete the user from the users table
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);

    // 2️⃣ Optionally, delete all sockets and usage logs related to this user
    final sockets = await db.query('sockets', where: 'id = ?', whereArgs: [userId]);
    for (var socket in sockets) {
      await db.delete('usage_logs', where: 'socketId = ?', whereArgs: [socket['id']]);
    }
    await db.delete('sockets', where: 'id = ?', whereArgs: [userId]);
  }

  // Update fingerprint preference
  static Future<void> updateFingerprintPreference(int userId, bool enabled) async {
    final db = await database;

    // You can store this however you want.
    // I’ll store it in "email" column as metadata (example).
    await db.update(
      'users',
      {'email': enabled ? 'FP_ENABLED' : 'FP_DISABLED'},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  static Future<void> saveSocketData(SocketData socket, {int? localId}) async {
    final db = await database;

    // We convert the SocketData object into a Map for SQLite
    final Map<String, dynamic> data = {
      'name': socket.id,
      'relayState': socket.relayState ? 1 : 0,
      'tripState': socket.tripState ? 1 : 0,
      'voltage': socket.voltage,
      'current': socket.current,
      'power': socket.power,
      'energy': socket.energy,
      'tripThreshold': socket.tripThreshold,
      'timestamp': socket.timestamp ?? DateTime.now().toIso8601String(),
      // Use jsonEncode to turn your Map<String, double> into a String for storage
      'dailyUsage': jsonEncode(socket.dailyUsage),
      'weeklyUsage': jsonEncode(socket.weeklyUsage),
    };

    if (localId != null) data['id'] = localId;

    // 1. Update/Insert the socket entry
    await db.insert(
        'sockets',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace
    );

    // 2. Log the raw data into history table (Settings UI can use this for charts)
    await db.insert('usage_logs', {
      'socketId': localId,
      'power': socket.power,
      'voltage': socket.voltage,
      'current': socket.current,
      'energy': socket.energy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<SocketData?> loadSocketData(int id) async {
    final db = await database;
    final res = await db.query('sockets', where: 'id = ?', whereArgs: [id]);

    if (res.isEmpty) return null;
    final row = res.first;

    // We rebuild the SocketData object from the SQLite row
    return SocketData(
      id: row['name'] as String,
      current: (row['current'] as num).toDouble(),
      tripThreshold: (row['tripThreshold'] as num).toDouble(),
      tripState: row['tripState'] == 1,
      relayState: row['relayState'] == 1,
      voltage: (row['voltage'] as num).toDouble(),
      power: (row['power'] as num).toDouble(),
      energy: (row['energy'] as num).toDouble(),
      timestamp: row['timestamp'] as String?,
      // Decode the JSON strings back into Map<String, double>
      dailyUsage: Map<String, double>.from(jsonDecode(row['dailyUsage'] as String)),
      weeklyUsage: Map<String, double>.from(jsonDecode(row['weeklyUsage'] as String)),
    );
  }

  /// -------------------
  /// SETTINGS UI HELPERS
  /// -------------------

  // Clears historical logs but keeps current settings
  static Future<void> clearUsageHistory(int socketId) async {
    final db = await database;
    await db.delete('usage_logs', where: 'socketId = ?', whereArgs: [socketId]);
  }

  // Pushes everything to Firebase for remote viewing
  static Future<void> syncToCloud() async {
    final db = await database;
    final List<Map<String, dynamic>> allSockets = await db.query('sockets');

    for (var s in allSockets) {
      await firebaseDb.child("sockets/${s['name']}").set({
        ...s,
        'dailyUsage': jsonDecode(s['dailyUsage']),
        'weeklyUsage': jsonDecode(s['weeklyUsage']),
      });
    }
  }
}