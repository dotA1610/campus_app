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

  Future<void> _handleSubmit() async {
    if (submitting) return;

    setState(() => submitting = true);

    try {
      final urls = widget.uploadedDocs
          .map((e) => (e['url'] ?? '').trim())
          .where((u) => u.isNotEmpty)
          .toList();

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
    final cs = Theme.of(context).colorScheme;

    final card = cs.surface;
    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final onCard = cs.onSurface;
    final muted = cs.onSurfaceVariant;

    Widget cardWrap({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: child,
      );
    }

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

    return DefaultTextStyle.merge(
      style: TextStyle(color: onCard),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          cardWrap(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: card2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Icon(Icons.fact_check_outlined, color: onCard),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Review Application",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: onCard),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "Verify everything before final submission to the HOD.",
                        style: TextStyle(fontSize: 12, color: muted),
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

          cardWrap(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: muted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "By submitting, you confirm the information provided is accurate.",
                    style: TextStyle(fontSize: 12, color: muted),
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
      ),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card = cs.surface;
    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final muted = cs.onSurfaceVariant;
    final onCard = cs.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Icon(icon, size: 18, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: onCard),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card = cs.surface;
    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final muted = cs.onSurfaceVariant;
    final onCard = cs.onSurface;

    final hasItems = items.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Icon(Icons.attach_file, size: 18, color: muted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Attachments", style: TextStyle(fontSize: 12, color: muted)),
                const SizedBox(height: 8),
                if (!hasItems)
                  Text(
                    "No file uploaded",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
                  )
                else
                  ...items.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text("• ", style: TextStyle(fontWeight: FontWeight.w900, color: onCard)),
                          Expanded(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: onCard),
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