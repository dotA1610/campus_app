import 'package:flutter/material.dart';
import '../services/subject_service.dart';

class SubjectRequestPage extends StatefulWidget {
  final VoidCallback? onSubmittedGoHistory;

  const SubjectRequestPage({super.key, this.onSubmittedGoHistory});

  @override
  State<SubjectRequestPage> createState() => _SubjectRequestPageState();
}

class _SubjectRequestPageState extends State<SubjectRequestPage> {
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
      // silent
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
          content: Text("You can only DROP a subject you are enrolled in."),
        ),
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

  // ---------------- UI HELPERS (THEME AWARE) ----------------

  Widget _cardWrap(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    Widget? trailing,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return _cardWrap(
      context,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Icon(icon, color: cs.onSurface),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    String text, {
    bool selected = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? cs.surfaceVariant : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.45) : cs.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge({
    required String text,
    required Color color,
  }) {
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

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    final cs = Theme.of(context).colorScheme;

    return _cardWrap(
      context,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(icon, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _enrolledTile(BuildContext context, Map<String, dynamic> row) {
    final cs = Theme.of(context).colorScheme;

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
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(Icons.book_outlined, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$code • $name",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "$credits credit hour(s)",
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildEnrolledSection(BuildContext context) {
    return _cardWrap(
      context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Currently Enrolled",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              _pill(context, "Reload", icon: Icons.refresh, onTap: _loadEnrolledOnly),
            ],
          ),
          const SizedBox(height: 10),
          if (enrolled.isEmpty)
            _emptyState(
              context,
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
                              child: _enrolledTile(context, e),
                            ))
                        .toList(),
                  );
                }

                final tiles = enrolled.map((e) => _enrolledTile(context, e)).toList();
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

  Widget _buildRequestFormSection(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sid = selectedSubjectId;
    final isEnrolled = sid != null && enrolledSubjectIds.contains(sid);

    return _cardWrap(
      context,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Submit Request",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
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

          Text("Subject", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: selectedSubjectId,
            dropdownColor: cs.surface,
            iconEnabledColor: cs.onSurface,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              filled: true,
              fillColor: cs.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.55)),
              ),
            ),
            items: subjects.map((s) {
              return DropdownMenuItem<String>(
                value: s['id'].toString(),
                child: Text(
                  _subjectLabel(s),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurface),
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

          Text("Action", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _pill(
                context,
                "ADD",
                icon: Icons.library_add,
                selected: actionType == "ADD",
                onTap: () => setState(() => actionType = "ADD"),
              ),
              _pill(
                context,
                "DROP",
                icon: Icons.delete_outline,
                selected: actionType == "DROP",
                onTap: () => setState(() => actionType = "DROP"),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text("Reason", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 8),

          TextField(
            controller: reasonController,
            maxLines: 4,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: "Why do you want to add/drop this subject?",
              hintStyle: TextStyle(color: cs.onSurfaceVariant),
              filled: true,
              fillColor: cs.surfaceVariant,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.primary.withOpacity(0.55)),
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
            context,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.onSurfaceVariant, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Your request will be reviewed by your HOD. Approved ADD enrolls you. Approved DROP removes you.",
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
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
          context,
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
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _emptyState(
              context,
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
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _sectionHeader(
              context,
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

            // ✅ ALWAYS STACKED
            _buildEnrolledSection(context),
            const SizedBox(height: 14),
            _buildRequestFormSection(context),
          ],
        ),
      ),
    );
  }
}