import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme.dart';
import 'pages/student_login_page.dart';
import 'pages/faculty_login_page.dart';
import 'layout/student_shell.dart';
import 'layout/faculty_shell.dart';
import 'services/auth_helper.dart'; // for getUserRole(), logout(), supabase

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

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  StreamSubscription<AuthState>? _authSub;

  bool _loading = true;

  /// If user is logged in, we decide shell by role
  bool _loggedIn = false;
  bool _isFaculty = false;

  /// Only for login screen toggling
  bool _showFacultyLogin = false;

  @override
  void initState() {
    super.initState();
    _boot();

    // React to login/logout automatically
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

      // Logged in -> decide role
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
      final role = await getUserRole(); // from auth_helper.dart
      final isFaculty = role == "hod";

      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _isFaculty = isFaculty;
        _loading = false;
      });
    } catch (_) {
      // If profile is broken or role can't be read, force logout to avoid weird UI state
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
    await logout(); // auth_helper.dart
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
      theme: buildDarkTheme(),
      home: _loading
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : _loggedIn
              ? (_isFaculty
                  ? FacultyShell(onLogout: _logout)
                  : StudentShell(onLogout: _logout))
              : (_showFacultyLogin
                  ? FacultyLoginPage(
                      onLogin: () async {
                        // FacultyLoginPage already logged in via loginFaculty()
                        // We just refresh role to pick correct shell
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
