import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'pages/student_login_page.dart';
import 'pages/faculty_login_page.dart';
import 'layout/student_shell.dart';
import 'layout/faculty_shell.dart';
import 'services/auth_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nznffbjmngyslchhzqja.supabase.co',
    anonKey: 'sb_publishable_EBKDK23A4vJy7R0eUGCydw_pvjWHIKt',
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
  bool _isFaculty = false;
  bool _showFacultyLogin = false;

  ThemeMode _themeMode = ThemeMode.dark; // default

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setState(() {
      _themeMode =
          (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
    });
  }

  void setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  // ✅ Helper for switches (Switch uses bool)
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
          _isFaculty = false;
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
        _isFaculty = false;
        _loading = false;
      });
      return;
    }
    await _refreshRole();
  }

  Future<void> _refreshRole() async {
    try {
      final role = await getUserRole();
      final isFaculty = role == "hod";

      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _isFaculty = isFaculty;
        _loading = false;
      });
    } catch (_) {
      await supabase.auth.signOut();
      if (!mounted) return;
      setState(() {
        _loggedIn = false;
        _isFaculty = false;
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
      _isFaculty = false;
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: _themeMode,

      home: _loading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _loggedIn
              ? (_isFaculty
                  ? FacultyShell(
                      onLogout: _logout,
                      isDarkMode: _isDarkMode,
                      onThemeChanged: _setDarkMode,
                    )
                  : StudentShell(
                      onLogout: _logout,
                      isDarkMode: _isDarkMode,
                      onThemeChanged: _setDarkMode,
                    ))
              : (_showFacultyLogin
                  ? FacultyLoginPage(
                      onLogin: () async {
                        setState(() => _loading = true);
                        await _refreshRole();
                      },
                      onBack: _switchToStudent,
                    )
                  : StudentLoginPage(
                      onLogin: () async {
                        setState(() => _loading = true);
                        await _refreshRole();
                      },
                      onFacultyTap: _switchToFaculty,
                    )),
    );
  }
}