import 'package:flutter/material.dart';
import '../services/auth_helper.dart';

class DashboardPage extends StatefulWidget {
  final VoidCallback onApplyLeaveTap;
  final VoidCallback onRecentActivityTap;

  const DashboardPage({
    super.key,
    required this.onApplyLeaveTap,
    required this.onRecentActivityTap,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = true;
  String? error;

  Map<String, dynamic>? profile;

  int approvedCount = 0;
  int pendingCount = 0;
  int rejectedCount = 0;

  Map<String, dynamic>? latestLeave;

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
      final p = await getMyProfile();

      final user = supabase.auth.currentUser;
      if (user == null) throw "Not logged in";

      final rows = await supabase
          .from('leave_applications')
          .select('status, created_at, leave_type, total_days')
          .eq('student_user_id', user.id)
          .order('created_at', ascending: false);

      int a = 0, pe = 0, r = 0;
      for (final item in (rows as List)) {
        final map = Map<String, dynamic>.from(item as Map);
        final status = (map['status'] ?? '').toString();
        if (status == 'Approved') a++;
        if (status == 'Pending') pe++;
        if (status == 'Rejected') r++;
      }

      final latest = (rows as List).isNotEmpty
          ? Map<String, dynamic>.from((rows as List).first as Map)
          : null;

      if (!mounted) return;
      setState(() {
        profile = p;
        approvedCount = a;
        pendingCount = pe;
        rejectedCount = r;
        latestLeave = latest;
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

  // Theme-aware "card wrapper"
  Widget _cardWrap(
    BuildContext context, {
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final Color cardColor =
        theme.cardTheme.color ?? cs.surface; // works for dark+light
    final Color borderColor =
        cs.outlineVariant.withOpacity(theme.brightness == Brightness.dark ? 0.55 : 0.8);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  // Theme-aware inner surface (for little boxes inside cards)
  BoxDecoration _innerBoxDeco(BuildContext context, {double radius = 16}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final inner = cs.surfaceVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.35 : 0.6,
    );
    final border = cs.outlineVariant.withOpacity(
      theme.brightness == Brightness.dark ? 0.45 : 0.7,
    );

    return BoxDecoration(
      color: inner,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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

    final name = _safe(profile?['full_name'], "Student");
    final studentId = _safe(profile?['student_id']);
    final course = _safe(profile?['course']);
    final semester = _safe(profile?['semester']);
    final faculty = _safe(profile?['faculty']);
    final batch = _safe(profile?['batch']);

    final latestStatus = _safe(latestLeave?['status'], '');
    final latestColor = latestLeave == null ? Colors.grey : _statusColor(latestStatus);

    final latestTitle = latestLeave == null
        ? "No leave applications yet"
        : "${_safe(latestLeave!['leave_type'], 'Leave')} • ${_safe(latestLeave!['status'], '')}";

    final latestSubtitle = latestLeave == null
        ? "Tap to view your leave history"
        : "${_safe(latestLeave!['total_days'], '-') } day(s)";

    return Container(
      color: theme.scaffoldBackgroundColor, // ✅ theme-aware background
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, c) {
            final isWide = c.maxWidth >= 980;

            final headerCard = _cardWrap(
              context,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: _innerBoxDeco(context, radius: 18),
                    child: Icon(Icons.person, color: theme.iconTheme.color ?? cs.onSurface),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back, $name 👋",
                          style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ) ??
                              const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _Pill(label: "ID: $studentId"),
                            _Pill(label: "Faculty: $faculty"),
                            _Pill(label: "Course: $course"),
                            _Pill(label: "Sem: $semester"),
                            _Pill(label: "Batch: $batch"),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            final quickActionCard = _cardWrap(
              context,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Quick Action",
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Apply for Leave",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800) ??
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Submit a new request for HOD approval.",
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onApplyLeaveTap,
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text("Start Application"),
                    ),
                  ),
                ],
              ),
            );

            final leaveSummaryCard = _cardWrap(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Leave Summary",
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800) ??
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Overview of your leave application statuses.",
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, c2) {
                      final tight = c2.maxWidth < 720;

                      final tiles = [
                        _SummaryTile(
                          label: "Approved",
                          value: approvedCount.toString(),
                          icon: Icons.check_circle,
                          accent: Colors.green,
                        ),
                        _SummaryTile(
                          label: "Pending",
                          value: pendingCount.toString(),
                          icon: Icons.hourglass_bottom,
                          accent: Colors.orange,
                        ),
                        _SummaryTile(
                          label: "Rejected",
                          value: rejectedCount.toString(),
                          icon: Icons.cancel,
                          accent: Colors.red,
                        ),
                      ];

                      if (tight) {
                        return Column(
                          children: [
                            tiles[0],
                            const SizedBox(height: 10),
                            tiles[1],
                            const SizedBox(height: 10),
                            tiles[2],
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: tiles[0]),
                          const SizedBox(width: 10),
                          Expanded(child: tiles[1]),
                          const SizedBox(width: 10),
                          Expanded(child: tiles[2]),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );

            final recentActivityCard = InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: widget.onRecentActivityTap,
              child: _cardWrap(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Recent Activity",
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800) ??
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Tap to open your leave application history.",
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                          const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: _innerBoxDeco(context, radius: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: _innerBoxDeco(context, radius: 14),
                            child: Icon(
                              latestLeave == null ? Icons.history : _statusIcon(latestStatus),
                              color: latestLeave == null ? Colors.grey : latestColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  latestTitle,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ) ??
                                      const TextStyle(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  latestSubtitle,
                                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                                      const TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );

            final quickCards = LayoutBuilder(
              builder: (context, c3) {
                final tight = c3.maxWidth < 900;

                final cards = <Widget>[
                  _QuickCard(
                    title: "Leave Applications",
                    subtitle: "View your full leave history and HOD remarks.",
                    icon: Icons.history,
                    onTap: widget.onRecentActivityTap,
                  ),
                  _QuickCard(
                    title: "Apply Leave",
                    subtitle: "Start a new leave request in seconds.",
                    icon: Icons.edit_calendar_outlined,
                    onTap: widget.onApplyLeaveTap,
                  ),
                ];

                if (tight) {
                  return Column(
                    children: [
                      cards[0],
                      const SizedBox(height: 12),
                      cards[1],
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              },
            );

            // ✅ Always stacked: Welcome THEN Apply-for-leave (works for wide + half screen)
            Widget topSection() {
              return Column(
                children: [
                  headerCard,
                  const SizedBox(height: 12),
                  quickActionCard, // ✅ full width now (no constraints)
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(18),
              children: [
                topSection(),
                const SizedBox(height: 16),

                if (isWide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leaveSummaryCard),
                      const SizedBox(width: 14),
                      SizedBox(width: 360, child: recentActivityCard),
                    ],
                  )
                else ...[
                  leaveSummaryCard,
                  const SizedBox(height: 12),
                  recentActivityCard,
                ],

                const SizedBox(height: 16),
                quickCards,
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------
// UI Components (Theme-aware)
// ------------------------------------------------------

class _Pill extends StatelessWidget {
  final String label;
  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = cs.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.28 : 0.55);
    final border = cs.outlineVariant.withOpacity(theme.brightness == Brightness.dark ? 0.45 : 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey) ??
            const TextStyle(fontSize: 11, color: Colors.grey),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final bg = cs.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.22 : 0.55);
    final border = cs.outlineVariant.withOpacity(theme.brightness == Brightness.dark ? 0.45 : 0.7);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(theme.brightness == Brightness.dark ? 0.25 : 0.7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                      const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final cardColor = theme.cardTheme.color ?? cs.surface;
    final border = cs.outlineVariant.withOpacity(theme.brightness == Brightness.dark ? 0.55 : 0.8);

    final iconBg = cs.surfaceVariant.withOpacity(theme.brightness == Brightness.dark ? 0.28 : 0.55);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: border),
              ),
              child: Icon(icon, color: theme.iconTheme.color ?? cs.onSurface),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey) ??
                        const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500),
          ],
        ),
      ),
    );
  }
}