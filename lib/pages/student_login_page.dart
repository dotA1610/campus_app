import 'package:flutter/material.dart';
import '../services/auth_helper.dart';

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
  // Match your dashboard vibe
  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

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

      // ✅ if the user is not student, sign out to prevent bad session state
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

  Widget _cardWrap({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  InputDecoration _inputDeco(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: icon == null ? null : Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: _card2,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _cardWrap(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: const [
                        Icon(Icons.school_outlined, color: Colors.white),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            "Student Login",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Sign in to view dashboard, apply leave, and track status.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: idController,
                      focusNode: _idFocus,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco("Student ID", icon: Icons.badge_outlined),
                      onSubmitted: (_) => _passFocus.requestFocus(),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: passController,
                      focusNode: _passFocus,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDeco("Password", icon: Icons.lock_outline),
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
