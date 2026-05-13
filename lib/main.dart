// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'auth/auth_wrapper.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static MyAppState? of(BuildContext context) {
    return context.findAncestorStateOfType<MyAppState>();
  }

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  String _currentTheme = 'light';

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    if (!mounted) return;
    setState(() {
      _currentTheme = theme;
    });
  }

  Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', theme);
    setState(() {
      _currentTheme = theme;
    });
  }

  // Legacy method for backward compatibility
  Future<void> toggleTheme() async {
    final newTheme = _currentTheme == 'light' ? 'dark' : 'light';
    await setTheme(newTheme);
  }

  ThemeData _getThemeData(String theme) {
    switch (theme) {
      case 'dark':
        return AppTheme.dark();
      case 'light':
      default:
        return AppTheme.light();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AttNote',
      theme: _getThemeData(_currentTheme),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}
