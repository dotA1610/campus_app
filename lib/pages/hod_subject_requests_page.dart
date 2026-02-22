import 'package:flutter/material.dart';
import '../services/auth_helper.dart';

class HodSubjectRequestsPage extends StatefulWidget {
  const HodSubjectRequestsPage({super.key});

  @override
  State<HodSubjectRequestsPage> createState() => _HodSubjectRequestsPageState();
}

class _HodSubjectRequestsPageState extends State<HodSubjectRequestsPage> {
  bool loading = true;
  String? error;

  String filter = "All";
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _safe(dynamic v, [String fallback = "-"]) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Not logged in";

      final matchMap = <String, Object>{
        'hod_user_id': user.id,
      };
      if (filter != "All") {
        matchMap['status'] = filter;
      }

      final rows = await supabase
          .from('subject_requests')
          .select('''
            id,
            student_user_id,
            subject_id,
            action_type,
            reason,
            status,
            hod_remark,
            created_at,
            subject:subject_id (
              subject_code,
              subject_name,
              credit_hours
            ),
            profiles:student_user_id (
              full_name,
              student_id,
              faculty
            )
          ''')
          .match(matchMap)
          .order('created_at', ascending: false);

      final mapped =
          (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (!mounted) return;
      setState(() {
        items = mapped;
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

  // ============================================================
  // ✅ CORE FIX: When HOD approves, also update subject_enrollments
  // ============================================================

  Future<void> _applyEnrollmentChange({
    required String studentUserId,
    required String subjectId,
    required String actionType, // ADD / DROP
  }) async {
    final action = actionType.toUpperCase().trim();

    if (action == "ADD") {
      final existing = await supabase
          .from('subject_enrollments')
          .select('id')
          .match({
            'student_user_id': studentUserId,
            'subject_id': subjectId,
          })
          .limit(1);

      final list = (existing as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (list.isNotEmpty) {
        await supabase.from('subject_enrollments').update({
          'status': 'ENROLLED',
        }).match({
          'student_user_id': studentUserId,
          'subject_id': subjectId,
        });
      } else {
        await supabase.from('subject_enrollments').insert({
          'student_user_id': studentUserId,
          'subject_id': subjectId,
          'status': 'ENROLLED',
        });
      }
    } else if (action == "DROP") {
      await supabase.from('subject_enrollments').update({
        'status': 'DROPPED',
      }).match({
        'student_user_id': studentUserId,
        'subject_id': subjectId,
      });
    }
  }

  Future<void> decideSubjectRequest({
    required Map<String, dynamic> row,
    required String newStatus, // Approved / Rejected
    required String hodRemark,
  }) async {
    final requestId = _safe(row['id'], '');
    if (requestId.isEmpty) throw "Invalid request id";

    final studentUserId = _safe(row['student_user_id'], '');
    final subjectId = _safe(row['subject_id'], '');
    final actionType = _safe(row['action_type'], '');

    await supabase.from('subject_requests').update({
      'status': newStatus,
      'hod_remark': hodRemark.trim().isEmpty ? null : hodRemark.trim(),
    }).match({'id': requestId});

    if (newStatus == "Approved") {
      if (studentUserId.isEmpty || subjectId.isEmpty) {
        throw "Missing student_user_id or subject_id in subject_requests row.";
      }
      await _applyEnrollmentChange(
        studentUserId: studentUserId,
        subjectId: subjectId,
        actionType: actionType,
      );
    }
  }

  Color _statusColor(String s) {
    if (s == "Approved") return Colors.green;
    if (s == "Rejected") return Colors.red;
    return Colors.orange;
  }

  IconData _statusIcon(String s) {
    if (s == "Approved") return Icons.check_circle;
    if (s == "Rejected") return Icons.cancel;
    return Icons.hourglass_bottom;
  }

  Color _actionColor(String a) {
    final up = a.toUpperCase();
    if (up == "ADD") return const Color(0xFF7C4DFF);
    if (up == "DROP") return const Color(0xFFFF5252);
    return Colors.grey;
  }

  IconData _actionIcon(String a) {
    final up = a.toUpperCase();
    if (up == "ADD") return Icons.playlist_add;
    if (up == "DROP") return Icons.playlist_remove;
    return Icons.swap_horiz;
  }

  String _fmtDate(dynamic v) {
    if (v == null) return "-";
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();
    const m = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${m[d.month - 1]} ${d.day}, ${d.year}";
  }

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

  Widget _filterPill(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    final selected = filter == label;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        setState(() => filter = label);
        await _load();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.surfaceVariant : cs.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? cs.primary.withOpacity(0.45) : cs.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Future<void> _openDecisionDialog(Map<String, dynamic> row, String newStatus) async {
    final controller = TextEditingController(
      text: (row['hod_remark'] ?? '').toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;

        return AlertDialog(
          backgroundColor: cs.surface,
          surfaceTintColor: cs.surface,
          title: Text(
            newStatus,
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "HOD Remark (optional)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(newStatus),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await decideSubjectRequest(
        row: row,
        newStatus: newStatus,
        hodRemark: controller.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == "Approved"
                ? "Approved ✅ Enrollment updated"
                : "Rejected ✅",
          ),
        ),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  Widget _emptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _cardWrap(
      context,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Icon(Icons.inbox_outlined, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "No requests found",
                  style: TextStyle(fontWeight: FontWeight.w900, color: cs.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  "Try another filter or check back later.",
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(BuildContext context, Map<String, dynamic> row) {
    final cs = Theme.of(context).colorScheme;

    final status = _safe(row['status'], 'Pending');
    final statusColor = _statusColor(status);

    final actionType = _safe(row['action_type'], '-');
    final reason = _safe(row['reason'], '-');
    final hodRemark = _safe(row['hod_remark'], '');
    final createdAt = _fmtDate(row['created_at']);

    final p = row['profiles'] is Map
        ? Map<String, dynamic>.from(row['profiles'])
        : <String, dynamic>{};

    final studentName = _safe(p['full_name'], 'Student');
    final studentId = _safe(p['student_id']);
    final faculty = _safe(p['faculty']);

    final s = row['subject'] is Map
        ? Map<String, dynamic>.from(row['subject'])
        : <String, dynamic>{};

    final subjectCode = _safe(s['subject_code']);
    final subjectName = _safe(s['subject_name']);
    final creditHours = _safe(s['credit_hours']);

    return _HoverCard(
      child: _cardWrap(
        context,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Icon(
                    _actionIcon(actionType),
                    color: _actionColor(actionType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "$studentName ($studentId)",
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(_statusIcon(status), size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              "Faculty: $faculty • Submitted: $createdAt",
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),

            const SizedBox(height: 12),

            Text(
              "$actionType • $subjectCode — $subjectName ($creditHours cr)",
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Text(
                reason,
                style: TextStyle(color: cs.onSurface),
              ),
            ),

            if (hodRemark.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                "HOD Remark: $hodRemark",
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],

            const SizedBox(height: 14),

            if (status == "Pending")
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openDecisionDialog(row, "Approved"),
                      child: const Text("Approve"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _openDecisionDialog(row, "Rejected"),
                      child: const Text("Reject"),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

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
              ElevatedButton(onPressed: _load, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            _cardWrap(
              context,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.library_add, color: cs.onSurface),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "HOD Subject Requests",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text("Refresh"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _filterPill(context, "All"),
                _filterPill(context, "Pending"),
                _filterPill(context, "Approved"),
                _filterPill(context, "Rejected"),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty) _emptyState(context),
            ...items.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _requestCard(context, row),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------
// Hover wrapper (nice on web, harmless on mobile)
// ------------------------------------------------------
class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: hovering
            ? (Matrix4.identity()..translate(0.0, -2.0))
            : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}