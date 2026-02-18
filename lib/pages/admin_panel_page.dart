import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_helper.dart';

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

class _AdminPanelPageState extends State<AdminPanelPage> {
  // --- THEME (match dashboard vibe) ---
  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  bool loading = true;
  String? error;

  String filter = "All"; // All / Pending / Approved / Rejected
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

  String _fmtDate(dynamic v) {
    if (v == null) return "-";
    final d = DateTime.tryParse(v.toString());
    if (d == null) return v.toString();

    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  // ✅ Match student side: support newline-separated OR comma-separated, remove duplicates
  List<String> _parseAttachmentUrls(dynamic v) {
    final raw = (v ?? '').toString().trim();
    if (raw.isEmpty) return [];

    final parts = raw
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final seen = <String>{};
    final out = <String>[];
    for (final p in parts) {
      if (seen.add(p)) out.add(p);
    }
    return out;
  }

  String _fileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segs = uri.pathSegments;
      final name = segs.isNotEmpty ? segs.last : url;
      return Uri.decodeComponent(name);
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl(String url) async {
    final u = url.trim();
    if (u.isEmpty) return;

    final uri = Uri.tryParse(u);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid attachment URL")),
      );
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open attachment")),
      );
    }
  }

  Widget _cardWrap({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
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

  Widget _filterPill(String label) {
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
          color: selected ? _card2 : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.white24 : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.grey,
          ),
        ),
      ),
    );
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
          .from('leave_applications')
          .select('''
            id,
            leave_type,
            start_date,
            end_date,
            total_days,
            reason,
            status,
            hod_remark,
            created_at,
            attachment_url,
            student:student_user_id (
              full_name,
              student_id,
              faculty
            )
          ''')
          .match(matchMap)
          .order('created_at', ascending: false);

      final mapped = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

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

  Future<void> _updateStatus({
    required String id,
    required String newStatus,
    required String hodRemark,
  }) async {
    await supabase.from('leave_applications').update({
      'status': newStatus,
      'hod_remark': hodRemark,
    }).match({'id': id});
  }

  Future<void> _openDecisionDialog(Map<String, dynamic> row, String newStatus) async {
    final id = _safe(row['id'], '');
    if (id.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid request id")),
      );
      return;
    }

    final controller = TextEditingController(
      text: (row['hod_remark'] ?? '').toString(),
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        title: Text(newStatus == "Approved" ? "Approve Request" : "Reject Request"),
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
      ),
    );

    if (ok != true) return;

    try {
      await _updateStatus(
        id: id,
        newStatus: newStatus,
        hodRemark: controller.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Updated: $newStatus ✅")),
      );

      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    }
  }

  Widget _emptyState() {
    return _cardWrap(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.inbox_outlined, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("No requests found", style: TextStyle(fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text(
                  "Try another filter or check back later.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final status = _safe(row['status'], 'Pending');
    final statusColor = _statusColor(status);

    final studentRaw = row['student'];
    final student = studentRaw is Map
        ? Map<String, dynamic>.from(studentRaw)
        : <String, dynamic>{};

    final studentName = _safe(student['full_name'], "Student");
    final studentId = _safe(student['student_id']);
    final faculty = _safe(student['faculty']);

    final leaveType = _safe(row['leave_type'], 'Leave');
    final start = _fmtDate(row['start_date']);
    final end = _fmtDate(row['end_date']);
    final days = _safe(row['total_days']);
    final reason = _safe(row['reason'], '-');
    final remark = _safe(row['hod_remark'], '');
    final createdAt = _fmtDate(row['created_at']);

    final attachments = _parseAttachmentUrls(row['attachment_url']);

    return _HoverCard(
      child: _cardWrap(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Icon(_statusIcon(status), color: statusColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$studentName ($studentId)",
                        style: const TextStyle(fontWeight: FontWeight.w900),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Faculty: $faculty • Submitted: $createdAt",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

            const SizedBox(height: 12),

            // LEAVE SUMMARY
            Text(
              "$leaveType • $start → $end ($days day(s))",
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 10),

            // REASON BOX
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Reason", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(reason),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // DETAILS (remark + attachments)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text(
                  "Details",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  (remark.isEmpty && attachments.isEmpty)
                      ? "No additional details"
                      : "View HOD remark / attachments",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                children: [
                  if (remark.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _card2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "HOD Remark",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(remark),
                          ],
                        ),
                      ),
                    ),

                  if (attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _card2,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Attachments",
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            ...attachments.map((url) {
                              final name = _fileNameFromUrl(url);
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _openUrl(url),
                                  icon: const Icon(Icons.attach_file, size: 18),
                                  label: Text(
                                    name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 6),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ACTIONS
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

    return Container(
      color: _bg,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            // HEADER
            _cardWrap(
              padding: const EdgeInsets.all(18),
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
                    child: const Icon(Icons.event_note, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "HOD Panel (Leave Requests)",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Approve / reject leave applications and review attachments.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
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

            // FILTERS
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _filterPill("All"),
                _filterPill("Pending"),
                _filterPill("Approved"),
                _filterPill("Rejected"),
              ],
            ),

            const SizedBox(height: 14),

            if (items.isEmpty) _emptyState(),

            ...items.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _requestCard(row),
                )),
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
