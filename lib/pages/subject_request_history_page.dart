import 'package:flutter/material.dart';
import '../services/auth_helper.dart';

class SubjectRequestHistoryPage extends StatefulWidget {
  const SubjectRequestHistoryPage({super.key});

  @override
  State<SubjectRequestHistoryPage> createState() =>
      _SubjectRequestHistoryPageState();
}

class _SubjectRequestHistoryPageState
    extends State<SubjectRequestHistoryPage> {
  // --- THEME (locked dashboard vibe) ---
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
        'student_user_id': user.id,
      };

      if (filter != "All") {
        matchMap['status'] = filter;
      }

      final rows = await supabase
          .from('subject_requests')
          .select('''
            id,
            action_type,
            reason,
            status,
            hod_remark,
            created_at,
            subject:subject_id (subject_code, subject_name, credit_hours)
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

  // ---------------- Helpers ----------------

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
        if (filter == label) return; // avoid useless reload
        setState(() => filter = label);
        await _load();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _card2 : _card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? Colors.white24 : _border),
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

  Widget _emptyState() {
    final message = filter == "All"
        ? "Submit one from Add/Drop Subject and it will appear here."
        : "No $filter requests found.";

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
            child: const Icon(Icons.inbox_outlined,
                color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("No subject requests yet",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> row) {
    final action =
        _safe(row['action_type'], 'ADD').toUpperCase();
    final status = _safe(row['status'], 'Pending');
    final statusColor = _statusColor(status);

    final subjectRaw = row['subject'];
    final subject = subjectRaw is Map
        ? Map<String, dynamic>.from(subjectRaw)
        : <String, dynamic>{};

    final code = _safe(subject['subject_code']);
    final name = _safe(subject['subject_name']);
    final credits = _safe(subject['credit_hours']);

    final created = _fmtDate(row['created_at']);
    final reason = _safe(row['reason']);
    final remark = _safe(row['hod_remark'], '');

    final aColor = _actionColor(action);
    final aIcon = _actionIcon(action);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
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
                child: Icon(aIcon, color: aColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      "$action • $code",
                      style: const TextStyle(
                          fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$name ($credits cr) • Submitted: $created",
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(999),
                  border: Border.all(
                      color:
                          statusColor.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    Icon(_statusIcon(status),
                        size: 14,
                        color: statusColor),
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

          // Reason box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text("Reason",
                    style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12)),
                const SizedBox(height: 6),
                Text(reason,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          if (remark.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text("HOD Remark",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(remark,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading)
      return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: _cardWrap(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Error: $error"),
              const SizedBox(height: 12),
              ElevatedButton(
                  onPressed: _load,
                  child: const Text("Retry")),
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
            _cardWrap(
              padding: const EdgeInsets.all(18),
              child: const Text(
                "My Subject Requests",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900),
              ),
            ),

            const SizedBox(height: 14),

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

            ...items.map(
              (row) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 12),
                child: _requestCard(row),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
