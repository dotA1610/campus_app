import 'package:flutter/material.dart';

class ApplyLeaveDetailsPage extends StatelessWidget {
  final String leaveType;
  final DateTime? startDate;
  final DateTime? endDate;
  final String reason;
  final int totalDays;

  final ValueChanged<String> onLeaveTypeChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<String> onReasonChanged;
  final VoidCallback onContinue;

  const ApplyLeaveDetailsPage({
    super.key,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.totalDays,
    required this.onLeaveTypeChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onReasonChanged,
    required this.onContinue,
  });

  Future<void> _pickDate(
    BuildContext context, {
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: current ?? now,
      builder: (ctx, child) {
        // make date picker follow your theme properly
        final theme = Theme.of(ctx);
        return Theme(
          data: theme,
          child: child!,
        );
      },
    );

    if (picked != null) onPicked(picked);
  }

  String _fmt(DateTime? d) {
    if (d == null) return "Select date";
    return "${_m(d.month)} ${d.day}, ${d.year}";
  }

  String _m(int m) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return months[m - 1];
  }

  Widget _sectionTitle(BuildContext context, String t, {String? subtitle}) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: cs.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final onCard = cs.onSurface;
    final muted = cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leave type
        _sectionTitle(
          context,
          "Leave Type",
          subtitle: "Select the category that best describes your leave.",
        ),
        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (ctx, c) {
            final isWide = c.maxWidth >= 900;

            final tiles = <Widget>[
              _TypeTile(
                label: "Sick",
                icon: Icons.local_hospital_outlined,
                selected: leaveType == "Sick",
                onTap: () => onLeaveTypeChanged("Sick"),
              ),
              _TypeTile(
                label: "Personal",
                icon: Icons.person_outline,
                selected: leaveType == "Personal",
                onTap: () => onLeaveTypeChanged("Personal"),
              ),
              _TypeTile(
                label: "Home",
                icon: Icons.home_outlined,
                selected: leaveType == "Home",
                onTap: () => onLeaveTypeChanged("Home"),
              ),
              _TypeTile(
                label: "Emergency",
                icon: Icons.warning_amber_outlined,
                selected: leaveType == "Emergency",
                onTap: () => onLeaveTypeChanged("Emergency"),
              ),
            ];

            if (!isWide) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: tiles[0]),
                      const SizedBox(width: 12),
                      Expanded(child: tiles[1]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: tiles[2]),
                      const SizedBox(width: 12),
                      Expanded(child: tiles[3]),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: tiles[0]),
                const SizedBox(width: 12),
                Expanded(child: tiles[1]),
                const SizedBox(width: 12),
                Expanded(child: tiles[2]),
                const SizedBox(width: 12),
                Expanded(child: tiles[3]),
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        // Duration
        _sectionTitle(
          context,
          "Duration",
          subtitle: "Pick the start and end date (inclusive).",
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _DateField(
                label: "From",
                value: _fmt(startDate),
                onTap: () => _pickDate(
                  context,
                  current: startDate ?? DateTime.now(),
                  onPicked: onStartDateChanged,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                label: "To",
                value: _fmt(endDate),
                onTap: () => _pickDate(
                  context,
                  current: endDate ?? startDate ?? DateTime.now(),
                  onPicked: onEndDateChanged,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Reason
        _sectionTitle(
          context,
          "Reason",
          subtitle: "Explain briefly. You can upload documents in the next step.",
        ),
        const SizedBox(height: 10),

        // ✅ Theme-driven TextField (works in light + dark)
        TextField(
          minLines: 3,
          maxLines: 5,
          style: TextStyle(color: onCard),
          decoration: InputDecoration(
            hintText: "Example: Fever and doctor appointment...",
            hintStyle: TextStyle(color: muted),
            filled: true,
            fillColor: card2,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.primary, width: 1.4),
            ),
          ),
          onChanged: onReasonChanged,
        ),

        const SizedBox(height: 6),

        if (reason.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              "Current: ${reason.trim()}",
              style: TextStyle(color: muted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 14),

        _InfoPill(
          left: totalDays.toString(),
          title: "Total Academic Days",
          icon: Icons.info_outline,
        ),

        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onContinue,
            icon: const Icon(Icons.arrow_forward),
            label: const Text("Continue"),
          ),
        ),
      ],
    );
  }
}

// ---------- small widgets used only here ----------

class _TypeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = selected ? cs.primary : cs.surfaceVariant;
    final fg = selected ? cs.onPrimary : cs.onSurface;
    final br = selected ? cs.primary.withOpacity(0.35) : cs.outlineVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: br),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected) Icon(Icons.check_circle, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final muted = cs.onSurfaceVariant;
    final onCard = cs.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: card2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined, size: 18, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: muted)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: onCard,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String left;
  final String title;
  final IconData icon;

  const _InfoPill({
    required this.left,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final card2 = cs.surfaceVariant;
    final border = cs.outlineVariant;
    final muted = cs.onSurfaceVariant;
    final onCard = cs.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: card2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.surface.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Text(
              left,
              style: TextStyle(fontWeight: FontWeight.w900, color: onCard),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w800, color: onCard),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, size: 18, color: muted),
        ],
      ),
    );
  }
}