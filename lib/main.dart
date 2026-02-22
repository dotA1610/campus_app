import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'pages/student_login_page.dart';
import 'pages/faculty_login_page.dart';

import 'layout/student_shell.dart';
import 'layout/faculty_shell.dart';
import 'layout/admin_shell.dart';

import 'services/auth_helper.dart';
import 'app/app_keyboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nznffbjmngyslchhzqja.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56bmZmYmptbmd5c2xjaGh6cWphIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4OTYwMjAsImV4cCI6MjA4NjQ3MjAyMH0.15qWz5NMfzx8ci9-LNlmeWYAhvM0ouQqO_y2_AkEzNM',
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  static _MyAppState of(BuildContext context) {
    final state = context.findAncestorStateOfType<_MyAppState>();
    if (state == null) {
      throw Exception("MyApp.of(context) failed: no _MyAppState found in tree.");
    }
    return state;
  }

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  bool _loading = true;
  bool _loggedIn = false;

  /// ✅ store the actual role: "student" / "hod" / "admin"
  String? _role;

  bool _showFacultyLogin = false;

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void _setDarkMode(bool isDark) {
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  bool get _isDarkMode => _themeMode == ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _boot();

    _authSub = supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;

      if (session == null) {
        if (!mounted) return;
        setState(() {
          _loggedIn = false;
          _role = null;
          _showFacultyLogin = false;
          _loading = false;
        });
        return;
      }

      await _refreshRole();
    });
  }

  Future<void> _boot() async {
    final session = supabase.auth.currentSession;

    if (session == null) {
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _role = null;
        _loading = false;
      });
      return;
    }

    await _refreshRole();
  }

  Future<void> _refreshRole() async {
    try {
      final role = (await getUserRole()).trim().toLowerCase();

      // ✅ only accept known roles
      if (role != "student" && role != "hod" && role != "admin") {
        await supabase.auth.signOut();
        if (!mounted) return;
        setState(() {
          _loggedIn = false;
          _role = null;
          _showFacultyLogin = false;
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _role = role;
        _loading = false;
      });
    } catch (_) {
      await supabase.auth.signOut();
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _role = null;
        _showFacultyLogin = false;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await logout();
    if (!mounted) return;
    setState(() {
      _loggedIn = false;
      _role = null;
      _showFacultyLogin = false;
    });
  }

  void _switchToFaculty() => setState(() => _showFacultyLogin = true);
  void _switchToStudent() => setState(() => _showFacultyLogin = false);

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Widget _home() {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      // ✅ Route by role
      if (_role == "admin") {
        return AdminShell(
          onLogout: _logout,
          isDarkMode: _isDarkMode,
          onThemeChanged: _setDarkMode,
        );
      }

      if (_role == "hod") {
        return FacultyShell(
          onLogout: _logout,
          isDarkMode: _isDarkMode,
          onThemeChanged: _setDarkMode,
        );
      }

      // student
      return StudentShell(
        onLogout: _logout,
        isDarkMode: _isDarkMode,
        onThemeChanged: _setDarkMode,
      );
    }

    // Not logged in → choose login screen
    if (_showFacultyLogin) {
      return FacultyLoginPage(
        onLogin: () async {
          setState(() => _loading = true);
          await _refreshRole();
        },
        onBack: _switchToStudent,
      );
    }

    return StudentLoginPage(
      onLogin: () async {
        setState(() => _loading = true);
        await _refreshRole();
      },
      onFacultyTap: _switchToFaculty,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,

      builder: (context, child) {
        return AppKeyboard(
          child: child ?? const SizedBox.shrink(),
        );
      },
      
      home: _home(),
    );
  }
}