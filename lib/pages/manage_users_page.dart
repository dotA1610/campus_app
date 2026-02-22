import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ✅ Hide global supabase vars to avoid name collision
import '../services/auth_helper.dart' hide supabase;

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final SupabaseClient _sb = Supabase.instance.client;

  bool loading = true;
  String? error;

  // Filters
  String roleFilter = "All"; // All / student / hod / admin
  String facultyFilter = "All";
  String search = "";

  // Pagination
  static const int pageSize = 20;
  int page = 0;

  // Data
  List<Map<String, dynamic>> users = [];
  List<String> faculties = [];

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load(resetPage: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _setError(String? msg) {
    if (!mounted) return;
    setState(() => error = msg);
  }

  void _setLoading(bool v) {
    if (!mounted) return;
    setState(() => loading = v);
  }

  Future<void> _load({bool resetPage = false}) async {
    if (!mounted) return;
    if (resetPage) page = 0;

    _setLoading(true);
    _setError(null);

    try {
      // ✅ Guard: only admin
      final role = (await getUserRole()).trim().toLowerCase();
      if (role != "admin") throw "Not an admin account.";

      final base = _sb.from('profiles').select('''
        id,
        role,
        full_name,
        student_id,
        staff_id,
        faculty,
        course,
        semester,
        batch
      ''');

      if (roleFilter != "All") {
        base.eq('role', roleFilter);
      }

      if (facultyFilter != "All") {
        base.eq('faculty', facultyFilter);
      }

      final s = search.trim();
      if (s.isNotEmpty) {
        final like = '%$s%';
        base.or(
          'full_name.ilike.$like,student_id.ilike.$like,staff_id.ilike.$like,faculty.ilike.$like,course.ilike.$like',
        );
      }

      final rows = await base
          .order('full_name', ascending: true)
          .range(page * pageSize, (page * pageSize) + pageSize - 1);

      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Faculties dropdown
      final facRows = await _sb
          .from('profiles')
          .select('faculty')
          .not('faculty', 'is', null);

      final facSet = <String>{};
      for (final r in (facRows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        final f = (m['faculty'] ?? '').toString().trim();
        if (f.isNotEmpty) facSet.add(f);
      }

      if (!mounted) return;
      setState(() {
        users = list;
        faculties = facSet.toList()..sort();
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      search = v;
      _load(resetPage: true);
    });
  }

  // -------------------------
  // ACTIONS
  // -------------------------

  Future<void> _editUserDialog(Map<String, dynamic> row) async {
    final id = (row['id'] ?? '').toString();
    if (id.isEmpty) return;

    final fullName =
        TextEditingController(text: (row['full_name'] ?? '').toString());
    final studentId =
        TextEditingController(text: (row['student_id'] ?? '').toString());
    final staffId =
        TextEditingController(text: (row['staff_id'] ?? '').toString());
    final faculty =
        TextEditingController(text: (row['faculty'] ?? '').toString());
    final course =
        TextEditingController(text: (row['course'] ?? '').toString());
    final semester =
        TextEditingController(text: (row['semester'] ?? '').toString());
    final batch = TextEditingController(text: (row['batch'] ?? '').toString());

    String role = (row['role'] ?? 'student').toString().toLowerCase();
    if (!['student', 'hod', 'admin'].contains(role)) role = 'student';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit User"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('student')),
                  DropdownMenuItem(value: 'hod', child: Text('hod')),
                  DropdownMenuItem(value: 'admin', child: Text('admin')),
                ],
                onChanged: (v) => role = (v ?? 'student'),
                decoration: const InputDecoration(labelText: "Role"),
              ),
              TextField(
                controller: fullName,
                decoration: const InputDecoration(labelText: "Full Name"),
              ),
              TextField(
                controller: studentId,
                decoration: const InputDecoration(labelText: "Student ID"),
              ),
              TextField(
                controller: staffId,
                decoration: const InputDecoration(labelText: "Staff ID"),
              ),
              TextField(
                controller: faculty,
                decoration: const InputDecoration(labelText: "Faculty"),
              ),
              TextField(
                controller: course,
                decoration: const InputDecoration(labelText: "Course"),
              ),
              TextField(
                controller: semester,
                decoration: const InputDecoration(labelText: "Semester"),
              ),
              TextField(
                controller: batch,
                decoration: const InputDecoration(labelText: "Batch"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _sb.from('profiles').update({
        'role': role,
        'full_name': fullName.text.trim().isEmpty ? null : fullName.text.trim(),
        'student_id':
            studentId.text.trim().isEmpty ? null : studentId.text.trim(),
        'staff_id': staffId.text.trim().isEmpty ? null : staffId.text.trim(),
        'faculty': faculty.text.trim().isEmpty ? null : faculty.text.trim(),
        'course': course.text.trim().isEmpty ? null : course.text.trim(),
        'semester': semester.text.trim().isEmpty ? null : semester.text.trim(),
        'batch': batch.text.trim().isEmpty ? null : batch.text.trim(),
      }).eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("User updated ✅")));
      await _load(resetPage: false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }

  // -------------------------
  // UI
  // -------------------------

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Error: $error"),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _load(resetPage: false),
              child: const Text("Retry"),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Manage Users",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              onPressed: () => _load(resetPage: false),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            labelText: "Search (name / student id / staff id / faculty / course)",
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DropdownButton<String>(
              value: roleFilter,
              items: const [
                DropdownMenuItem(value: "All", child: Text("All roles")),
                DropdownMenuItem(value: "student", child: Text("student")),
                DropdownMenuItem(value: "hod", child: Text("hod")),
                DropdownMenuItem(value: "admin", child: Text("admin")),
              ],
              onChanged: (v) {
                roleFilter = v ?? "All";
                _load(resetPage: true);
              },
            ),
            DropdownButton<String>(
              value: facultyFilter,
              items: [
                const DropdownMenuItem(
                    value: "All", child: Text("All faculties")),
                ...faculties
                    .map((f) => DropdownMenuItem(value: f, child: Text(f))),
              ],
              onChanged: (v) {
                facultyFilter = v ?? "All";
                _load(resetPage: true);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (users.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Center(child: Text("No users found.")),
          )
        else
          ...users.map((u) {
            final name = (u['full_name'] ?? '-').toString();
            final role = (u['role'] ?? '-').toString();
            final faculty = (u['faculty'] ?? '-').toString();
            final studentId = (u['student_id'] ?? '').toString();
            final staffId = (u['staff_id'] ?? '').toString();

            return Card(
              child: ListTile(
                title: Text("$name • $role"),
                subtitle: Text(
                  [
                    if (studentId.isNotEmpty) "Student: $studentId",
                    if (staffId.isNotEmpty) "Staff: $staffId",
                    "Faculty: $faculty",
                  ].join(" • "),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editUserDialog(u),
                ),
              ),
            );
          }).toList(),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton(
              onPressed: page <= 0
                  ? null
                  : () {
                      page--;
                      _load(resetPage: false);
                    },
              child: const Text("Prev"),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: users.length < pageSize
                  ? null
                  : () {
                      page++;
                      _load(resetPage: false);
                    },
              child: const Text("Next"),
            ),
            const SizedBox(width: 12),
            Text("Page ${page + 1}",
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ],
    );
  }
}