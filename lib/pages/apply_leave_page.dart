import 'package:flutter/material.dart';
import 'apply_leave_details_page.dart';
import 'apply_leave_documents_page.dart';
import 'apply_leave_review_page.dart';

class ApplyLeavePage extends StatefulWidget {
  final VoidCallback onSubmittedGoDashboard;

  const ApplyLeavePage({
    super.key,
    required this.onSubmittedGoDashboard,
  });

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  int step = 0;

  String leaveType = "Sick";
  DateTime? startDate;
  DateTime? endDate;
  String reason = "";

  // ✅ multiple docs: [{name,url}]
  List<Map<String, String>> uploadedDocs = [];

  int get totalDays {
    if (startDate == null || endDate == null) return 0;
    final diff = endDate!.difference(startDate!).inDays + 1;
    return diff < 0 ? 0 : diff;
  }

  void next() => setState(() => step = (step + 1).clamp(0, 2));
  void back() => setState(() => step = (step - 1).clamp(0, 2));

  void _resetWizard() {
    step = 0;
    leaveType = "Sick";
    startDate = null;
    endDate = null;
    reason = "";
    uploadedDocs = [];
  }

  String _stepTitle(int s) {
    if (s == 0) return "Details";
    if (s == 1) return "Documents";
    return "Review";
  }

  String _stepSubtitle(int s) {
    if (s == 0) return "Choose leave type, dates, and write your reason.";
    if (s == 1) return "Upload supporting documents (optional).";
    return "Confirm everything before submitting.";
  }

  Widget _cardWrap({
    required Widget child,
    required Color cardColor,
    required Color borderColor,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Theme-driven colors (works in light + dark)
    final bg = theme.scaffoldBackgroundColor;
    final card = theme.cardTheme.color ?? cs.surface;
    final card2 = cs.surfaceVariant; // secondary surface block
    final border = cs.outlineVariant; // nice subtle border in both themes
    final onCard = cs.onSurface;
    final muted = cs.onSurfaceVariant;

    Widget stepBody() {
      if (step == 0) {
        return ApplyLeaveDetailsPage(
          leaveType: leaveType,
          startDate: startDate,
          endDate: endDate,
          reason: reason,
          totalDays: totalDays,
          onLeaveTypeChanged: (v) => setState(() => leaveType = v),
          onStartDateChanged: (v) => setState(() => startDate = v),
          onEndDateChanged: (v) => setState(() => endDate = v),
          onReasonChanged: (v) => setState(() => reason = v),
          onContinue: () {
            if (startDate == null || endDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Please select start and end date")),
              );
              return;
            }
            if (endDate!.isBefore(startDate!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("End date cannot be before start date")),
              );
              return;
            }
            next();
          },
        );
      }

      if (step == 1) {
        return ApplyLeaveDocumentsPage(
          leaveType: leaveType,
          uploadedDocs: uploadedDocs,
          onChanged: (list) => setState(() => uploadedDocs = list),
          onBack: back,
          onContinue: next,
        );
      }

      if (startDate == null || endDate == null) {
        return Center(
          child: _cardWrap(
            cardColor: card,
            borderColor: border,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Dates not selected. Please go back.", style: TextStyle(color: onCard)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() => step = 0),
                  child: const Text("Back to Details"),
                ),
              ],
            ),
          ),
        );
      }

      return ApplyLeaveReviewPage(
        leaveType: leaveType,
        startDate: startDate!,
        endDate: endDate!,
        totalDays: totalDays,
        reason: reason,
        uploadedDocs: uploadedDocs,
        onBack: back,
        onSubmitted: () {
          setState(_resetWizard);
          widget.onSubmittedGoDashboard();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Leave submitted ✅")),
          );
        },
      );
    }

    return Container(
      color: bg,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          // HEADER
          _cardWrap(
            cardColor: card,
            borderColor: border,
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
                  child: Icon(
                    Icons.edit_calendar_outlined,
                    color: onCard,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Apply for Leave",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: onCard,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepSubtitle(step),
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: card2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    "Step ${step + 1}/3 • ${_stepTitle(step)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // STEPPER / PROGRESS
          _cardWrap(
            cardColor: card,
            borderColor: border,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (ctx, c) {
                    final tight = c.maxWidth < 520;
                    final lineMargin = tight ? 6.0 : 10.0;

                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StepDot(
                              index: 0,
                              current: step,
                              label: "Details",
                              card2: card2,
                              border: border,
                            ),
                          ),
                        ),
                        _StepLine(active: step >= 1, margin: lineMargin),
                        Expanded(
                          child: Center(
                            child: _StepDot(
                              index: 1,
                              current: step,
                              label: "Documents",
                              card2: card2,
                              border: border,
                            ),
                          ),
                        ),
                        _StepLine(active: step >= 2, margin: lineMargin),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _StepDot(
                              index: 2,
                              current: step,
                              label: "Review",
                              card2: card2,
                              border: border,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (step + 1) / 3,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: card2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // BODY CARD
          _cardWrap(
            cardColor: card,
            borderColor: border,
            padding: const EdgeInsets.all(14),
            child: stepBody(),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final int current;
  final String label;

  // theme-driven surfaces
  final Color card2;
  final Color border;

  const _StepDot({
    required this.index,
    required this.current,
    required this.label,
    required this.card2,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final done = current > index;
    final active = current == index;

    final Color ring = done
        ? Colors.green
        : active
            ? cs.primary
            : cs.onSurfaceVariant;

    final Color fill = done
        ? Colors.green.withOpacity(0.14)
        : active
            ? cs.primary.withOpacity(0.14)
            : card2;

    final labelColor = (active || done) ? cs.onSurface : cs.onSurfaceVariant;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ring.withOpacity(0.55)),
          ),
          child: Icon(
            done ? Icons.check : Icons.circle,
            size: done ? 18 : 10,
            color: ring,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  final bool active;
  final double margin;

  const _StepLine({
    required this.active,
    this.margin = 10,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: margin),
        decoration: BoxDecoration(
          color: active ? cs.primary : cs.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}