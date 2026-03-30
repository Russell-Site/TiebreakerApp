// lib/main.dart
// Entry point for Tiebreaker AI
// Loads environment variables and sets up the app with theme management

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tiebreaker_ai/theme/app_theme.dart';
import 'package:tiebreaker_ai/screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

// Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TiebreakerApp());
}

class TiebreakerApp extends StatefulWidget {
  const TiebreakerApp({super.key});

  @override
  State<TiebreakerApp> createState() => _TiebreakerAppState();
}

class _TiebreakerAppState extends State<TiebreakerApp> {
  // Tracks whether dark mode is active
  bool _isDarkMode = false;

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BreakPoint',
      debugShowCheckedModeBanner: false,

      // Apply custom themes
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,

      home: HomeScreen(
        onToggleTheme: _toggleTheme,
        isDarkMode: _isDarkMode,
      ),
    );
  }
}