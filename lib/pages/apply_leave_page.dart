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
  // --- THEME (locked dashboard vibe) ---
  static const _bg = Color(0xFF0B0B0F);
  static const _card = Color(0xFF14141A);
  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);

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

  @override
  Widget build(BuildContext context) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Dates not selected. Please go back."),
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
      color: _bg,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  child: const Icon(
                    Icons.edit_calendar_outlined,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Apply for Leave",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _stepSubtitle(step),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _card2,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    "Step ${step + 1}/3 • ${_stepTitle(step)}",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // STEPPER / PROGRESS
          _cardWrap(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (ctx, c) {
                    // responsive spacing (prevents overflow on small widths)
                    final tight = c.maxWidth < 520;
                    final lineMargin = tight ? 6.0 : 10.0;

                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _StepDot(index: 0, current: step, label: "Details"),
                          ),
                        ),
                        _StepLine(active: step >= 1, margin: lineMargin),
                        Expanded(
                          child: Center(
                            child: _StepDot(index: 1, current: step, label: "Documents"),
                          ),
                        ),
                        _StepLine(active: step >= 2, margin: lineMargin),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _StepDot(index: 2, current: step, label: "Review"),
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
                  backgroundColor: _card2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // BODY CARD
          _cardWrap(
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

  const _StepDot({
    required this.index,
    required this.current,
    required this.label,
  });

  static const _card2 = Color(0xFF101014);

  @override
  Widget build(BuildContext context) {
    final done = current > index;
    final active = current == index;

    final Color ring = done
        ? Colors.green
        : active
            ? const Color(0xFF7C4DFF)
            : Colors.grey;

    final Color fill = done
        ? Colors.green.withOpacity(0.18)
        : active
            ? const Color(0xFF7C4DFF).withOpacity(0.18)
            : _card2;

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
            color: active || done ? Colors.white : Colors.grey,
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
    return Expanded(
      child: Container(
        height: 2,
        margin: EdgeInsets.symmetric(horizontal: margin),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C4DFF) : const Color(0xFF24242D),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
