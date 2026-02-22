import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_helper.dart';
import 'manage_users_page.dart';

class AdminDashboardPage extends StatefulWidget {
  final VoidCallback onOpenManageUsers;

  const AdminDashboardPage({
    super.key,
    required this.onOpenManageUsers,
  });

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool loading = true;
  String? error;

  _Counts leaveCounts = _Counts.zero();
  _Counts subjectCounts = _Counts.zero();

  List<_ActivityItem> activity = [];

  bool settingsTableMissing = false;
  List<_SettingRow> settings = [];

  bool auditTableMissing = false;
  List<_AuditRow> auditLogs = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
      settingsTableMissing = false;
      auditTableMissing = false;
    });

    try {
      final role = (await getUserRole()).trim().toLowerCase();
      if (role != "admin") throw "Not an admin account.";

      final results = await Future.wait([
        _loadCounts(table: "leave_applications"),
        _loadCounts(table: "subject_requests"),
        _loadRecentActivity(),
        _loadSystemSettings(),
        _loadAuditLogs(),
      ]);

      if (!mounted) return;
      setState(() {
        leaveCounts = results[0] as _Counts;
        subjectCounts = results[1] as _Counts;
        activity = results[2] as List<_ActivityItem>;
        settings = results[3] as List<_SettingRow>;
        auditLogs = results[4] as List<_AuditRow>;
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

  // -----------------------------
  // DATA LOADERS
  // -----------------------------

  Future<_Counts> _loadCounts({required String table}) async {
    // NOTE: This is “simple but heavy” (it fetches IDs).
    // If your dataset grows big, we’ll replace with RPC count function.
    final totalRows = await supabase.from(table).select('id');
    final pendingRows =
        await supabase.from(table).select('id').eq('status', 'Pending');
    final approvedRows =
        await supabase.from(table).select('id').eq('status', 'Approved');
    final rejectedRows =
        await supabase.from(table).select('id').eq('status', 'Rejected');

    return _Counts(
      total: (totalRows as List).length,
      pending: (pendingRows as List).length,
      approved: (approvedRows as List).length,
      rejected: (rejectedRows as List).length,
    );
  }

  Future<List<_ActivityItem>> _loadRecentActivity() async {
    final leaveRows = await supabase
        .from('leave_applications')
        .select('id, student_user_id, leave_type, status, created_at')
        .order('created_at', ascending: false)
        .limit(8);

    final subjectRows = await supabase
        .from('subject_requests')
        .select('id, student_user_id, action_type, status, created_at')
        .order('created_at', ascending: false)
        .limit(8);

    final List<_ActivityItem> out = [];

    for (final r in (leaveRows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      out.add(_ActivityItem(
        kind: _ActivityKind.leave,
        id: (m['id'] ?? '').toString(),
        status: (m['status'] ?? 'Pending').toString(),
        title: "Leave • ${(m['leave_type'] ?? 'Leave').toString()}",
        subtitle: "Student: ${(m['student_user_id'] ?? '').toString()}",
        createdAt: _tryParseDate(m['created_at']),
      ));
    }

    for (final r in (subjectRows as List)) {
      final m = Map<String, dynamic>.from(r as Map);
      final action = (m['action_type'] ?? 'ADD').toString().toUpperCase();
      out.add(_ActivityItem(
        kind: _ActivityKind.subject,
        id: (m['id'] ?? '').toString(),
        status: (m['status'] ?? 'Pending').toString(),
        title: "Subject • $action request",
        subtitle: "Student: ${(m['student_user_id'] ?? '').toString()}",
        createdAt: _tryParseDate(m['created_at']),
      ));
    }

    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out.take(12).toList();
  }

  Future<List<_SettingRow>> _loadSystemSettings() async {
    try {
      final rows = await supabase
          .from('system_settings')
          .select('key, value, updated_at')
          .order('key', ascending: true);

      return (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _SettingRow(
          keyName: (m['key'] ?? '').toString(),
          value: (m['value'] ?? '').toString(),
          updatedAt: _tryParseDate(m['updated_at']),
        );
      }).toList();
    } catch (_) {
      settingsTableMissing = true;
      return [];
    }
  }

  Future<List<_AuditRow>> _loadAuditLogs() async {
    try {
      final rows = await supabase
          .from('audit_logs')
          .select(
              'id, actor_user_id, action, target_table, target_id, meta, created_at')
          .order('created_at', ascending: false)
          .limit(12);

      return (rows as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return _AuditRow(
          id: (m['id'] ?? '').toString(),
          actorUserId: (m['actor_user_id'] ?? '').toString(),
          action: (m['action'] ?? '').toString(),
          targetTable: (m['target_table'] ?? '').toString(),
          targetId: (m['target_id'] ?? '').toString(),
          meta: m['meta'],
          createdAt: _tryParseDate(m['created_at']),
        );
      }).toList();
    } catch (_) {
      auditTableMissing = true;
      return [];
    }
  }

  Future<void> _upsertSetting(String keyName, String value) async {
    await supabase.from('system_settings').upsert({
      'key': keyName,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'key');

    await _logAudit(
      action: "system_settings.update",
      targetTable: "system_settings",
      targetId: keyName,
      meta: {'value': value},
    );
  }

  Future<void> _logAudit({
    required String action,
    required String targetTable,
    required String targetId,
    Map<String, dynamic>? meta,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      await supabase.from('audit_logs').insert({
        'actor_user_id': user?.id,
        'action': action,
        'target_table': targetTable,
        'target_id': targetId,
        'meta': meta,
      });
    } catch (_) {
      // ignore
    }
  }

  // -----------------------------
  // UI HELPERS
  // -----------------------------

  static DateTime _tryParseDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final d = DateTime.tryParse(v.toString());
    return d ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fmtDate(DateTime d) {
    const months = [
      "Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"
    ];
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }

  Color _statusColor(String s, ColorScheme cs) {
    final t = s.trim().toLowerCase();
    if (t == "approved") return Colors.green;
    if (t == "rejected") return Colors.red;
    if (t == "pending") return Colors.orange;
    return cs.primary;
  }

  IconData _statusIcon(String s) {
    final t = s.trim().toLowerCase();
    if (t == "approved") return Icons.check_circle;
    if (t == "rejected") return Icons.cancel;
    if (t == "pending") return Icons.hourglass_bottom;
    return Icons.info_outline;
  }

  Widget _cardWrap({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
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
    final cs = Theme.of(context).colorScheme;
    return _cardWrap(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.primary.withOpacity(0.20)),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w900)),
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

  Widget _miniStatCard({
    required IconData icon,
    required String title,
    required String big,
    required String sub,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.primary.withOpacity(0.20)),
            ),
            child: Icon(icon, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(big,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdownPills(_Counts c, ColorScheme cs) {
    Widget pill(String label, int value, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Text(
          "$label: $value",
          style: TextStyle(
              color: color, fontWeight: FontWeight.w900, fontSize: 11),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        pill("Pending", c.pending, Colors.orange),
        pill("Approved", c.approved, Colors.green),
        pill("Rejected", c.rejected, Colors.red),
        pill("Total", c.total, cs.primary),
      ],
    );
  }

  // -----------------------------
  // DIALOGS
  // -----------------------------

  Future<void> _editSettingDialog(_SettingRow row) async {
    final controller = TextEditingController(text: row.value);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Edit setting: ${row.keyName}"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: "Value",
            hintText: "Enter new value",
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _upsertSetting(row.keyName, controller.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Updated ${row.keyName} ✅")));
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Update failed: $e")));
    }
  }

  // -----------------------------
  // BUILD
  // -----------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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

    final totalPending = leaveCounts.pending + subjectCounts.pending;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _sectionHeader(
            title: "Admin Overview",
            subtitle: "System-wide monitoring, settings, and logs.",
            icon: Icons.shield_outlined,
            trailing: TextButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("Refresh"),
            ),
          ),

          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (ctx, c) {
              final wide = c.maxWidth >= 900;

              final cards = [
                _miniStatCard(
                  icon: Icons.event_note_outlined,
                  title: "Leave Applications",
                  big: "${leaveCounts.total}",
                  sub: "${leaveCounts.pending} pending",
                ),
                _miniStatCard(
                  icon: Icons.swap_horiz,
                  title: "Subject Requests",
                  big: "${subjectCounts.total}",
                  sub: "${subjectCounts.pending} pending",
                ),
                _miniStatCard(
                  icon: Icons.pending_actions_outlined,
                  title: "Total Pending",
                  big: "$totalPending",
                  sub: "Needs review",
                ),
              ];

              if (!wide) {
                return Column(
                  children: [
                    cards[0],
                    const SizedBox(height: 12),
                    cards[1],
                    const SizedBox(height: 12),
                    cards[2],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),

          const SizedBox(height: 14),

          _cardWrap(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Breakdown",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),

                const Text("Leave Applications",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                _breakdownPills(leaveCounts, cs),

                const SizedBox(height: 14),

                const Text("Subject Requests",
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 8),
                _breakdownPills(subjectCounts, cs),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Recent Activity
          _cardWrap(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Recent Activity",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                if (activity.isEmpty)
                  const Text("No activity yet.", style: TextStyle(color: Colors.grey))
                else
                  ...activity.map((a) {
                    final color = _statusColor(a.status, cs);
                    final icon = _statusIcon(a.status);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: theme.dividerColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: color.withOpacity(0.22)),
                              ),
                              child: Icon(icon, color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title,
                                      style: const TextStyle(fontWeight: FontWeight.w900),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Text(a.subtitle,
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_fmtDate(a.createdAt),
                                    style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 2),
                                Text(_fmtTime(a.createdAt),
                                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _prettyMeta(dynamic meta) {
    if (meta == null) return "";
    try {
      if (meta is String) return meta;
      if (meta is Map || meta is List) return jsonEncode(meta);
      return meta.toString();
    } catch (_) {
      return "";
    }
  }
}

// -----------------------------
// MODELS
// -----------------------------

class _Counts {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  const _Counts({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory _Counts.zero() =>
      const _Counts(total: 0, pending: 0, approved: 0, rejected: 0);
}

enum _ActivityKind { leave, subject }

class _ActivityItem {
  final _ActivityKind kind;
  final String id;
  final String status;
  final String title;
  final String subtitle;
  final DateTime createdAt;

  _ActivityItem({
    required this.kind,
    required this.id,
    required this.status,
    required this.title,
    required this.subtitle,
    required this.createdAt,
  });
}

class _SettingRow {
  final String keyName;
  final String value;
  final DateTime updatedAt;

  _SettingRow({
    required this.keyName,
    required this.value,
    required this.updatedAt,
  });
}

class _AuditRow {
  final String id;
  final String actorUserId;
  final String action;
  final String targetTable;
  final String targetId;
  final dynamic meta;
  final DateTime createdAt;

  _AuditRow({
    required this.id,
    required this.actorUserId,
    required this.action,
    required this.targetTable,
    required this.targetId,
    required this.meta,
    required this.createdAt,
  });
}