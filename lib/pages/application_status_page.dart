import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_helper.dart';

class ApplicationStatusPage extends StatefulWidget {
  const ApplicationStatusPage({super.key});

  @override
  State<ApplicationStatusPage> createState() => _ApplicationStatusPageState();
}

class _ApplicationStatusPageState extends State<ApplicationStatusPage> {
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

  List<String> _parseAttachmentUrls(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return [];

    // support: newline-separated OR comma-separated
    final parts = s
        .split(RegExp(r'[\n,]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // remove duplicates (preserve order)
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
      if (uri.pathSegments.isEmpty) return url;
      return Uri.decodeComponent(uri.pathSegments.last);
    } catch (_) {
      return url;
    }
  }

  Future<void> _openUrl(String url) async {
    final cleaned = url.trim();
    if (cleaned.isEmpty) return;

    final uri = Uri.tryParse(cleaned);
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

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "Not logged in";

      final Map<String, Object> matchMap = {
        'student_user_id': user.id,
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
            attachment_url,
            created_at
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
            fontWeight: FontWeight.w700,
            color: selected ? cs.onSurface : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
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
                  "No applications found",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Try a different filter or submit a new leave request.",
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaveCard(BuildContext context, Map<String, dynamic> row) {
    final cs = Theme.of(context).colorScheme;

    final status = _safe(row['status'], 'Pending');
    final color = _statusColor(status);

    final leaveType = _safe(row['leave_type'], 'Leave');
    final start = _fmtDate(row['start_date']);
    final end = _fmtDate(row['end_date']);
    final days = _safe(row['total_days']);
    final reason = _safe(row['reason'], '-');
    final remark = _safe(row['hod_remark'], '');
    final createdAt = _fmtDate(row['created_at']);
    final attachmentRaw = _safe(row['attachment_url'], '');
    final attachments = _parseAttachmentUrls(attachmentRaw);

    return _cardWrap(
      context,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          LayoutBuilder(
            builder: (context, c) {
              final tight = c.maxWidth < 520;

              final left = Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Icon(_statusIcon(status), color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$leaveType • $start → $end",
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$days day(s) • Submitted: $createdAt",
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withOpacity(0.25)),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              );

              if (!tight) {
                return Row(
                  children: [
                    Expanded(child: left),
                    badge,
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  left,
                  const SizedBox(height: 10),
                  badge,
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Reason
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Reason", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  reason,
                  style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Details (remark + attachments)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                "Details",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              subtitle: Text(
                (remark.isEmpty && attachments.isEmpty)
                    ? "No additional details"
                    : "View HOD remark / attachments",
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
              children: [
                if (remark.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("HOD Remark",
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 6),
                          Text(
                            remark,
                            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
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
                        color: cs.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Attachments",
                              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 10),
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
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
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
            // Header
            _cardWrap(
              context,
              padding: const EdgeInsets.all(18),
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
                    child: Icon(Icons.history, color: cs.onSurface),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "My Leave Applications",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Track status, review HOD remarks, and open attachments.",
                          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Filters
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
                child: _leaveCard(context, row),
              ),
            ),
          ],
        ),
      ),
    );
  }
}