import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'app.db');

    return await openDatabase(
      path,
      version: 3, // bumped to version 3 to include fingerprint
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT,
        passwordHash TEXT NOT NULL,
        fingerprintEnabled INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE sockets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        power REAL DEFAULT 0.0,
        energy REAL DEFAULT 0.0,
        threshold REAL DEFAULT 0.0
      )
    ''');

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
    if (oldVersion < 2) {
      // Safe add email column if it doesn't exist
      final res = await db.rawQuery("PRAGMA table_info(users)");
      final columns = res.map((c) => c['name'].toString()).toList();
      if (!columns.contains('email')) {
        await db.execute("ALTER TABLE users ADD COLUMN email TEXT");
      }
    }
    if (oldVersion < 3) {
      // Safe add fingerprintEnabled column if it doesn't exist
      final res = await db.rawQuery("PRAGMA table_info(users)");
      final columns = res.map((c) => c['name'].toString()).toList();
      if (!columns.contains('fingerprintEnabled')) {
        await db.execute("ALTER TABLE users ADD COLUMN fingerprintEnabled INTEGER DEFAULT 0");
      }
    }
  }

  /// -------------------
  /// Get User by ID
  /// -------------------
  static Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  /// -------------------
  /// USER FUNCTIONS
  /// -------------------
  static Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return await db.insert('users', user, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final res = await db.query('users', where: 'username = ?', whereArgs: [username]);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<int> updateUsername(int id, String newUsername) async {
    final db = await database;
    return await db.update(
      'users',
      {'username': newUsername},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updateEmail(int id, String newEmail) async {
    final db = await database;
    return await db.update(
      'users',
      {'email': newEmail},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> updatePassword(int id, String newPassHash) async {
    final db = await database;
    return await db.update(
      'users',
      {'passwordHash': newPassHash},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
    await db.delete('sockets');
    await db.delete('usage_logs');
  }

  /// -------------------
  /// FINGERPRINT FUNCTIONS
  /// -------------------
  static Future<int> updateFingerprintPreference(int id, bool value) async {
    final db = await database;
    // Ensure column exists before update
    final res = await db.rawQuery("PRAGMA table_info(users)");
    final columns = res.map((c) => c['name'].toString()).toList();
    if (!columns.contains('fingerprintEnabled')) {
      await db.execute("ALTER TABLE users ADD COLUMN fingerprintEnabled INTEGER DEFAULT 0");
    }

    return await db.update(
      'users',
      {'fingerprintEnabled': value ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<bool> getFingerprintPreference(int id) async {
    final db = await database;
    final res = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return false;
    return (res.first['fingerprintEnabled'] ?? 0) == 1;
  }

  static Future<bool> isFingerprintEnabled(int id) async {
    final db = await database;
    final res = await db.query(
      'users',
      columns: ['fingerprintEnabled'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return res.isNotEmpty && (res.first['fingerprintEnabled'] == 1);
  }

  /// -------------------
  /// SOCKET FUNCTIONS
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

  static Future<Map<String, dynamic>?> getSocketById(int id) async {
    final db = await database;
    final res = await db.query("sockets", where: "id = ?", whereArgs: [id]);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<Map<String, dynamic>?> getSocketByName(String name) async {
    final db = await database;
    final res = await db.query("sockets", where: "name = ?", whereArgs: [name]);
    return res.isNotEmpty ? res.first : null;
  }

  static Future<int> updateSocketState({
    required int id,
    double? power,
    double? energy,
    double? threshold,
  }) async {
    final db = await database;

    final updates = <String, dynamic>{};
    if (power != null) updates['power'] = power;
    if (energy != null) updates['energy'] = energy;
    if (threshold != null) updates['threshold'] = threshold;

    return await db.update(
      'sockets',
      updates,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<int> deleteSocket(int id) async {
    final db = await database;
    return await db.delete('sockets', where: 'id = ?', whereArgs: [id]);
  }

  /// -------------------
  /// USAGE LOGGING
  /// -------------------
  static Future<int> insertUsage({
    required int socketId,
    required double power,
    required double voltage,
    required double current,
    required double energy,
  }) async {
    final db = await database;

    return await db.insert('usage_logs', {
      'socketId': socketId,
      'power': power,
      'voltage': voltage,
      'current': current,
      'energy': energy,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, dynamic>>> getUsageForSocket(int socketId) async {
    final db = await database;
    return await db.query(
      'usage_logs',
      where: 'socketId = ?',
      whereArgs: [socketId],
      orderBy: 'timestamp ASC',
    );
  }
}
