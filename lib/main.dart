import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'loginPage.dart';

// Modern color palette
const Color darkBg = Color(0xFF0f172a);
const Color cardBg = Color(0xFF1f2937);
const Color borderColor = Color(0xFF374151);
const Color primaryAccent = Color(0xFF06b6d4);
const Color successGreen = Color(0xFF10b981);
const Color warningAmber = Color(0xFFd97706);
const Color dangerRed = Color(0xFFef4444);
const Color textPrimary = Color(0xFFe5e7eb);
const Color textSecondary = Color(0xFF9ca3af);

/// ---------------------------------------------
///  MAIN — Initialize Firebase here
/// ---------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const IntelligentSocketApp());
}


class IntelligentSocketApp extends StatefulWidget {
  const IntelligentSocketApp({Key? key}) : super(key: key);

  @override
  State<IntelligentSocketApp> createState() => _IntelligentSocketAppState();
}

class _IntelligentSocketAppState extends State<IntelligentSocketApp> {
  bool _isDarkMode = false; // false = dark, true = light

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Socket',
      debugShowCheckedModeBanner: false,

      // THEMES
      theme: ThemeData.light(),
      darkTheme: _buildDarkTheme(),

      // SWITCH THEME MODE
      themeMode: _isDarkMode ? ThemeMode.light : ThemeMode.dark,

      home: LoginPage(
        isDarkMode: _isDarkMode,
        onThemeChanged: (isLightMode) {
          setState(() => _isDarkMode = isLightMode);
        },
      ),
    );
  }

  /// ---------------------------------------------
  /// Custom Dark Theme
  /// ---------------------------------------------
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
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 16,
          color: textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardBg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF111827),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryAccent, width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
