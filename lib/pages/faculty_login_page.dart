import 'package:flutter/material.dart';
import '../services/auth_helper.dart';
import '../main.dart'; // for MyApp.of(context).toggleTheme()

class FacultyLoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  final VoidCallback onBack;

  const FacultyLoginPage({
    super.key,
    required this.onLogin,
    required this.onBack,
  });

  @override
  State<FacultyLoginPage> createState() => _FacultyLoginPageState();
}

class _FacultyLoginPageState extends State<FacultyLoginPage> {
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

  String _prettyError(Object e) {
    final msg = e.toString();

    if (msg.contains("Please enter Staff ID and Password")) {
      return "Please enter Staff ID and Password";
    }

    // From auth_helper.dart
    if (msg.contains("Not a faculty/admin account")) {
      return "Not a faculty/admin account";
    }

    // Supabase common auth errors
    if (msg.toLowerCase().contains("invalid login credentials")) {
      return "Invalid credentials. Please check your Staff ID and password.";
    }

    // fallback
    return "Login failed. Please check your credentials and try again.";
  }

  Future<void> handleLogin() async {
    if (loading) return;

    FocusScope.of(context).unfocus();

    setState(() {
      error = null;
      loading = true;
    });

    try {
      final staffId = idController.text.trim();
      final password = passController.text.trim();

      if (staffId.isEmpty || password.isEmpty) {
        throw AuthHelperException("Please enter Staff ID and Password");
      }

      // ✅ loginFaculty already enforces: hod OR admin (based on your auth_helper.dart)
      await loginFaculty(
        staffId: staffId,
        password: password,
      );

      if (!mounted) return;
      widget.onLogin();
    } catch (e) {
      _setError(_prettyError(e));
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
    final cardColor =
        Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

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
                    Row(
                      children: [
                        IconButton(
                          onPressed: loading ? null : widget.onBack,
                          icon: const Icon(Icons.arrow_back),
                          tooltip: "Back",
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            "Faculty / Admin Login",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                        IconButton(
                          tooltip: isDark ? "Switch to Light Mode" : "Switch to Dark Mode",
                          onPressed: () => MyApp.of(context).toggleTheme(),
                          icon: Icon(
                            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sign in with your staff account (HOD or Admin).",
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: idController,
                      focusNode: _idFocus,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: _inputDeco(context, "Staff ID", icon: Icons.badge_outlined),
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
                          textAlign: TextAlign.left,
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

                    TextButton(
                      onPressed: loading ? null : widget.onBack,
                      child: const Text("Back to Student Login"),
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