import 'package:flutter/material.dart';
import '../services/auth_helper.dart';

class ApplyLeaveReviewPage extends StatefulWidget {
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final int totalDays;
  final String reason;

  /// Multiple docs: [{ "name": "...", "url": "..." }, ...]
  final List<Map<String, String>> uploadedDocs;

  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  const ApplyLeaveReviewPage({
    super.key,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.reason,
    required this.uploadedDocs,
    required this.onBack,
    required this.onSubmitted,
  });

  @override
  State<ApplyLeaveReviewPage> createState() => _ApplyLeaveReviewPageState();
}

class _ApplyLeaveReviewPageState extends State<ApplyLeaveReviewPage> {
  // --- THEME (match dashboard vibe) ---
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  bool submitting = false;

  String _fmt(DateTime d) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return "${months[d.month - 1]} ${d.day}, ${d.year}";
  }

  String _safe(String? v, [String fallback = "-"]) {
    final s = (v ?? "").trim();
    return s.isEmpty ? fallback : s;
  }

  String _fileNameFromUrl(String url) {
    try {
      final u = Uri.parse(url);
      final seg = u.pathSegments.isNotEmpty ? u.pathSegments.last : url;
      return Uri.decodeComponent(seg);
    } catch (_) {
      return url;
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

  Future<void> _handleSubmit() async {
    if (submitting) return;

    setState(() => submitting = true);

    try {
      final urls = widget.uploadedDocs
          .map((e) => (e['url'] ?? '').trim())
          .where((u) => u.isNotEmpty)
          .toList();

      // ✅ Store multiple URLs newline-separated (simple + works with your HOD page)
      final attachmentUrl = urls.join('\n');

      await submitLeaveApplication(
        leaveType: widget.leaveType,
        startDate: widget.startDate,
        endDate: widget.endDate,
        totalDays: widget.totalDays,
        reason: widget.reason,
        attachmentUrl: attachmentUrl,
      );

      if (!mounted) return;
      widget.onSubmitted();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Submit failed: $e")),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationText =
        "${_fmt(widget.startDate)} → ${_fmt(widget.endDate)} (${widget.totalDays} day(s))";

    final reasonText = _safe(widget.reason, "-");

    final attachmentNames = widget.uploadedDocs.map((m) {
      final name = (m['name'] ?? '').trim();
      if (name.isNotEmpty) return name;
      final url = (m['url'] ?? '').trim();
      if (url.isNotEmpty) return _fileNameFromUrl(url);
      return "Attachment";
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: const Icon(Icons.fact_check_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Review Application",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      "Verify everything before final submission to the HOD.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        _ReviewTile(
          icon: Icons.medical_services_outlined,
          title: "Leave Type",
          value: "${widget.leaveType} Leave",
        ),
        const SizedBox(height: 12),
        _ReviewTile(
          icon: Icons.calendar_month_outlined,
          title: "Duration",
          value: durationText,
        ),
        const SizedBox(height: 12),
        _ReviewTile(
          icon: Icons.description_outlined,
          title: "Reason",
          value: reasonText,
        ),
        const SizedBox(height: 12),
        _AttachmentsTile(items: attachmentNames),

        const SizedBox(height: 12),

        _cardWrap(
          padding: const EdgeInsets.all(12),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: Colors.grey),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "By submitting, you confirm the information provided is accurate.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: submitting ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: submitting ? null : _handleSubmit,
                icon: const Icon(Icons.send),
                label: Text(submitting ? "Submitting..." : "Submit"),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _ReviewTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Icon(icon, size: 18, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentsTile extends StatelessWidget {
  final List<String> items;

  const _AttachmentsTile({required this.items});

  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

  @override
  Widget build(BuildContext context) {
    final hasItems = items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF14141A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.attach_file, size: 18, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Attachments", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 8),
                if (!hasItems)
                  const Text(
                    "No file uploaded",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey,
                    ),
                  )
                else
                  ...items.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Text("• ", style: TextStyle(fontWeight: FontWeight.w900)),
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
