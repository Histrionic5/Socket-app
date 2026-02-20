import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'Dashboard.dart';
import 'package:my_wife/Database/LocalDatabase.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;

  const LoginPage({
    Key? key,
    required this.isDarkMode,
    required this.onThemeChanged,
  }) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  bool _isSignIn = true;
  bool _fingerprintEnabled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFingerprintPreference();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  Future<void> _loadFingerprintPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('fingerprint_enabled') ?? false;
    setState(() => _fingerprintEnabled = enabled);
  }

  Future<void> _saveFingerprintPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fingerprint_enabled', enabled);
    setState(() => _fingerprintEnabled = enabled);
  }

  void _showTempError(String message) {
    setState(() => _errorMessage = message);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _errorMessage = '');
    });
  }

  Future<bool> _loginOffline(String username, String password) async {
    final user = await LocalDatabase.getUserByUsername(username);
    return user != null && user['passwordHash'] == _hashPassword(password);
  }

  Future<void> _login() async {
    setState(() => _loading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showTempError("Enter username/email and password");
        return;
      }

      // Offline login first
      final offlineSuccess = await _loginOffline(username, password);
      if (offlineSuccess) {
        await _goToDashboard();
        return;
      }

      // Firebase login
      final email = username.contains('@') ? username : "$username@app.com";
      await _auth
          .signInWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      // Save locally
      await LocalDatabase.insertUser({
        'username': username,
        'email': email,
        'passwordHash': _hashPassword(password),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);

      if (!_fingerprintEnabled) _askFingerprintPermission();

      await _goToDashboard();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        _showTempError("Please confirm credentials");
      } else {
        _showTempError("Login failed: ${e.message}");
      }
    } catch (e) {
      _showTempError("Login failed. Check connection.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    setState(() => _loading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final email = _emailController.text.trim().isEmpty
          ? "$username@app.com"
          : _emailController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        _showTempError("Enter username and password");
        return;
      }

      await _auth
          .createUserWithEmailAndPassword(email: email, password: password)
          .timeout(const Duration(seconds: 10));

      await LocalDatabase.insertUser({
        'username': username,
        'email': email,
        'passwordHash': _hashPassword(password),
      });

      final existingSockets = await LocalDatabase.getAllSockets();
      if (existingSockets.isEmpty) await LocalDatabase.insertSocket("Main Socket");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      await prefs.setString('password', password);

      _askFingerprintPermission();
      await _goToDashboard();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        _showTempError("Create Account failed: Username/email already exists");
      } else {
        _showTempError("Create Account failed: ${e.message}");
      }
    } catch (e) {
      _showTempError("Create Account failed. Check connection.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _usernameController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showTempError("Enter your email to reset password");
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email: email);
      _showTempError("Password reset email sent");
    } catch (e) {
      _showTempError("Failed to send reset email");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithFingerprint() async {
    setState(() => _loading = true);
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isAvailable = await _localAuth.isDeviceSupported();
      if (!canCheck || !isAvailable) {
        _showTempError("Biometric login not available");
        return;
      }

      bool authenticated = await _localAuth.authenticate(
        localizedReason: "Authenticate to log in",
        biometricOnly: true,
      );

      if (authenticated) {
        final prefs = await SharedPreferences.getInstance();
        final storedUsername = prefs.getString('username') ?? '';
        final storedPassword = prefs.getString('password') ?? '';

        if (storedUsername.isNotEmpty && storedPassword.isNotEmpty) {
          _usernameController.text = storedUsername;
          _passwordController.text = storedPassword;
          await _login();
        }
      }
    } catch (e) {
      _showTempError("Fingerprint failed");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goToDashboard() async {
    List<Map<String, dynamic>> sockets = await LocalDatabase.getAllSockets();

    if (sockets.isEmpty) {
      await LocalDatabase.insertSocket("Main Socket");
      sockets = await LocalDatabase.getAllSockets();
    }

    if (sockets.isEmpty) {
      _showTempError("No sockets available");
      return;
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          selectedSockets: [sockets[0]['id']],
          socketName: sockets[0]['name'],
        ),
      ),
    );
  }

  void _askFingerprintPermission() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Enable Fingerprint Login?"),
        content: const Text("Use fingerprint login for faster access on this device?"),
        actions: [
          TextButton(
            onPressed: () {
              _saveFingerprintPreference(false);
              Navigator.pop(context);
            },
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () {
              _saveFingerprintPreference(true);
              Navigator.pop(context);
            },
            child: const Text("Yes"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        title: const Text("Smart Socket"),
        backgroundColor: cardBg,
        actions: [
          Switch(
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
            activeColor: primaryAccent,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _isSignIn = true),
                      child: Text(
                        "Log In",
                        style: TextStyle(
                          color: _isSignIn ? primaryAccent : textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _isSignIn = false),
                      child: Text(
                        "Create Account",
                        style: TextStyle(
                          color: !_isSignIn ? primaryAccent : textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBg,
                    hintText: _isSignIn ? "Username or Email" : "Username",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  style: const TextStyle(color: textPrimary),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: cardBg,
                    hintText: "Password",
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                        color: textSecondary,
                      ),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  style: const TextStyle(color: textPrimary),
                ),
                if (!_isSignIn) const SizedBox(height: 20),
                if (!_isSignIn)
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      hintText: "Email (Optional)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    style: const TextStyle(color: textPrimary),
                  ),
                const SizedBox(height: 10),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: dangerRed, fontSize: 14),
                  ),
                const SizedBox(height: 10),
                if (_isSignIn)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _forgotPassword,
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: primaryAccent),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : (_isSignIn ? _login : _signUp),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _loading ? "Loading..." : (_isSignIn ? "Log In" : "Create Account"),
                    style: const TextStyle(fontSize: 18, color: textPrimary),
                  ),
                ),
                const SizedBox(height: 10),
                if (_fingerprintEnabled)
                  TextButton.icon(
                    onPressed: _loginWithFingerprint,
                    icon: const Icon(Icons.fingerprint, color: primaryAccent),
                    label: const Text("Log in with Fingerprint", style: TextStyle(color: primaryAccent)),
                  ),
                if (_fingerprintEnabled)
                  TextButton(
                    onPressed: () => _saveFingerprintPreference(false),
                    child: const Text("Cancel Fingerprint Login", style: TextStyle(color: dangerRed)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
