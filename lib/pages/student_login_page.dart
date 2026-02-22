import 'package:flutter/material.dart';
import '../services/auth_helper.dart';
import '../main.dart'; // ✅ for MyApp.of(context).toggleTheme()

class StudentLoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onFacultyTap;

  const StudentLoginPage({
    super.key,
    required this.onLogin,
    required this.onFacultyTap,
  });

  @override
  State<StudentLoginPage> createState() => _StudentLoginPageState();
}

class _StudentLoginPageState extends State<StudentLoginPage> {
  final idController = TextEditingController();
  final passController = TextEditingController();

  final _idFocus = FocusNode();
  final _passFocus = FocusNode();

  String? error;
  bool loading = false;

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => error = msg);
  }

  Future<void> handleLogin() async {
    if (loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      error = null;
      loading = true;
    });

    try {
      final studentId = idController.text.trim();
      final password = passController.text.trim();

      if (studentId.isEmpty || password.isEmpty) {
        throw "Please enter Student ID and Password";
      }

      await loginStudent(
        studentId: studentId,
        password: password,
      );

      final role = await getUserRole();

      if (role != "student") {
        await supabase.auth.signOut();
        throw "Not a student account";
      }

      if (!mounted) return;
      widget.onLogin();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains("Student ID and Password")) {
        _setError("Please enter Student ID and Password");
      } else if (msg.contains("Not a student account")) {
        _setError("This account is not a student account.");
      } else {
        _setError("Login failed. Please check your credentials and try again.");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    idController.dispose();
    passController.dispose();
    _idFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Widget _cardWrap(BuildContext context, {required Widget child}) {
    final border = Theme.of(context).dividerColor;
    final cardColor = Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  InputDecoration _inputDeco(BuildContext context, String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _cardWrap(
                context,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header + Theme toggle
                    Row(
                      children: [
                        const Icon(Icons.school_outlined),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            "Student Login",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                          onPressed: () => MyApp.of(context).toggleTheme(),
                          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sign in to view dashboard, apply leave, and track status.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: idController,
                      focusNode: _idFocus,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: _inputDeco(context, "Student ID", icon: Icons.badge_outlined),
                      onSubmitted: (_) => _passFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: passController,
                      focusNode: _passFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      decoration: _inputDeco(context, "Password", icon: Icons.lock_outline),
                      onSubmitted: (_) => handleLogin(),
                    ),

                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.red.withOpacity(0.25)),
                        ),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: loading ? null : handleLogin,
                        child: loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text("Sign In"),
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: loading ? null : widget.onFacultyTap,
                      icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                      label: const Text("Faculty Login"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}