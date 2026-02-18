import 'package:flutter/material.dart';
import '../services/subject_service.dart';

class SubjectRequestPage extends StatefulWidget {
  final VoidCallback? onSubmittedGoHistory;

  const SubjectRequestPage({super.key, this.onSubmittedGoHistory});

  @override
  State<SubjectRequestPage> createState() => _SubjectRequestPageState();
}

class _SubjectRequestPageState extends State<SubjectRequestPage> {
  // --- THEME (match your web vibe) ---
  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  bool loading = true;
  String? error;

  // dropdown subjects
  List<Map<String, dynamic>> subjects = [];
  String? selectedSubjectId;

  // enrolled subjects
  List<Map<String, dynamic>> enrolled = [];
  final Set<String> enrolledSubjectIds = {};

  String actionType = "ADD"; // ADD / DROP
  final reasonController = TextEditingController();

  bool submitting = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final subjectRows = await fetchSubjects();
      final enrolledRows = await fetchMyEnrolledSubjects();

      if (!mounted) return;

      final ids = <String>{};
      for (final e in enrolledRows) {
        final subjectMap = (e['subject'] is Map)
            ? Map<String, dynamic>.from(e['subject'] as Map)
            : <String, dynamic>{};
        final sid = (e['subject_id'] ?? subjectMap['id'] ?? '').toString();
        if (sid.isNotEmpty) ids.add(sid);
      }

      setState(() {
        subjects = subjectRows;
        enrolled = enrolledRows;

        enrolledSubjectIds
          ..clear()
          ..addAll(ids);

        selectedSubjectId =
            subjectRows.isNotEmpty ? subjectRows.first['id']?.toString() : null;

        final initId = selectedSubjectId;
        if (initId != null) {
          actionType = enrolledSubjectIds.contains(initId) ? "DROP" : "ADD";
        }

        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = "$e";
        loading = false;
      });
    }
  }

  Future<void> _loadEnrolledOnly() async {
    try {
      final enrolledRows = await fetchMyEnrolledSubjects();
      if (!mounted) return;

      final ids = <String>{};
      for (final e in enrolledRows) {
        final subjectMap = (e['subject'] is Map)
            ? Map<String, dynamic>.from(e['subject'] as Map)
            : <String, dynamic>{};
        final sid = (e['subject_id'] ?? subjectMap['id'] ?? '').toString();
        if (sid.isNotEmpty) ids.add(sid);
      }

      setState(() {
        enrolled = enrolledRows;
        enrolledSubjectIds
          ..clear()
          ..addAll(ids);
      });
    } catch (_) {
      // keep silent
    }
  }

  String _subjectLabel(Map<String, dynamic> s) {
    final code = (s['subject_code'] ?? '').toString();
    final name = (s['subject_name'] ?? '').toString();
    final credits = (s['credit_hours'] ?? '').toString();
    return "$code • $name ($credits cr)";
  }

  Map<String, dynamic>? _findSubjectById(String subjectId) {
    try {
      return subjects
          .firstWhere((s) => (s['id'] ?? '').toString() == subjectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit() async {
    if (submitting) return;

    FocusScope.of(context).unfocus();

    final sid = selectedSubjectId;
    if (sid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No subject selected")),
      );
      return;
    }

    final isEnrolled = enrolledSubjectIds.contains(sid);

    if (actionType == "DROP" && !isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("You can only DROP a subject you are enrolled in.")),
      );
      return;
    }

    if (actionType == "ADD" && isEnrolled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are already enrolled in this subject.")),
      );
      return;
    }

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a reason")),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      await submitSubjectRequest(
        subjectId: sid,
        actionType: actionType,
        reason: reason,
      );

      if (!mounted) return;

      final picked = _findSubjectById(sid);
      final pickedLabel = picked == null ? "Subject" : _subjectLabel(picked);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Request submitted ✅ ($actionType) • $pickedLabel")),
      );

      reasonController.clear();

      await _loadEnrolledOnly();
      widget.onSubmittedGoHistory?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit failed: $e")),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  // ---------------- UI HELPERS ----------------

  Widget _cardWrap(
      {required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _sectionHeader({
    required String title,
    String? subtitle,
    Widget? trailing,
    IconData? icon,
  }) {
    return _cardWrap(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _pill(String text,
      {bool selected = false, VoidCallback? onTap, IconData? icon}) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _card2 : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.white24 : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return _cardWrap(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _enrolledTile(Map<String, dynamic> row) {
    final subjectRaw = row['subject'];
    final subject = subjectRaw is Map
        ? Map<String, dynamic>.from(subjectRaw)
        : <String, dynamic>{};

    final code = (subject['subject_code'] ?? '-').toString();
    final name = (subject['subject_name'] ?? '-').toString();
    final credits = (subject['credit_hours'] ?? '-').toString();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.book_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$code • $name",
                  style: const TextStyle(fontWeight: FontWeight.w900),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "$credits credit hour(s)",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildEnrolledSection(double maxWidth) {
    return _cardWrap(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Currently Enrolled",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              _pill("Reload", icon: Icons.refresh, onTap: _loadEnrolledOnly),
            ],
          ),
          const SizedBox(height: 10),
          if (enrolled.isEmpty)
            _emptyState(
              icon: Icons.inbox_outlined,
              title: "No enrolled subjects yet",
              subtitle: "Once a subject is enrolled, it will appear here.",
            )
          else
            LayoutBuilder(
              builder: (ctx, c) {
                final wideGrid = c.maxWidth >= 820;
                if (!wideGrid) {
                  return Column(
                    children: enrolled
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _enrolledTile(e),
                            ))
                        .toList(),
                  );
                }

                final tiles = enrolled.map(_enrolledTile).toList();
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(tiles.length, (i) {
                    return SizedBox(
                      width: (c.maxWidth - 12) / 2,
                      child: tiles[i],
                    );
                  }),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRequestFormSection() {
    final sid = selectedSubjectId;
    final isEnrolled = sid != null && enrolledSubjectIds.contains(sid);

    return _cardWrap(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Submit Request",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
              if (sid != null)
                _badge(
                  text: isEnrolled ? "ENROLLED" : "NOT ENROLLED",
                  color: isEnrolled ? Colors.green : Colors.orange,
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Subject", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selectedSubjectId,
            dropdownColor: _card2,
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
            items: subjects.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'].toString(),
                child: Text(
                  _subjectLabel(s),
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) {
              setState(() {
                selectedSubjectId = v;
                final vEnrolled = v != null && enrolledSubjectIds.contains(v);
                actionType = vEnrolled ? "DROP" : "ADD";
              });
            },
          ),
          const SizedBox(height: 14),
          const Text("Action", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(
                "ADD",
                icon: Icons.library_add,
                selected: actionType == "ADD",
                onTap: () => setState(() => actionType = "ADD"),
              ),
              _pill(
                "DROP",
                icon: Icons.delete_outline,
                selected: actionType == "DROP",
                onTap: () => setState(() => actionType = "DROP"),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text("Reason", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: reasonController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Why do you want to add/drop this subject?",
              hintStyle: const TextStyle(color: Colors.grey),
              filled: true,
              fillColor: _card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: submitting ? null : _submit,
              icon: const Icon(Icons.send),
              label: Text(submitting ? "Submitting..." : "Submit Request"),
            ),
          ),
          const SizedBox(height: 8),
          _cardWrap(
            padding: const EdgeInsets.all(12),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.grey, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Your request will be reviewed by your HOD. Approved ADD enrolls you. Approved DROP removes you.",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- BUILD ----------------

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: _cardWrap(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Error: $error"),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadAll, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    if (subjects.isEmpty) {
      return Container(
        color: _bg,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _emptyState(
              icon: Icons.warning_amber_rounded,
              title: "No subjects found",
              subtitle: "Your subject table is empty OR SELECT is blocked (RLS).",
              action: TextButton(onPressed: _loadAll, child: const Text("Refresh")),
            ),
          ),
        ),
      );
    }

    return Container(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _sectionHeader(
              title: "Add/Drop Subject",
              subtitle:
                  "Submit request → HOD reviews → your enrollment updates after approval.",
              icon: Icons.swap_horiz,
              trailing: TextButton.icon(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Refresh"),
              ),
            ),
            const SizedBox(height: 14),

            // ✅ ALWAYS STACKED (full screen OR half screen)
            _buildEnrolledSection(double.infinity),
            const SizedBox(height: 14),
            _buildRequestFormSection(),
          ],
        ),
      ),
    );
  }
}
