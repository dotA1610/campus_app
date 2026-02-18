import 'package:flutter/material.dart';

class StepperHeader extends StatelessWidget {
  final int step; // 0,1,2

  const StepperHeader({
    super.key,
    required this.step,
  });

  static const _card2 = Color(0xFF101014);
  static const _border = Color(0xFF24242D);
  static const _accent = Color(0xFF7C4DFF);

  @override
  Widget build(BuildContext context) {
    const labels = ["Details", "Documents", "Review"];

    return Row(
      children: List.generate(3, (index) {
        final isActive = index == step;
        final isDone = index < step;

        Color ringColor;
        Color fillColor;
        Color textColor;

        if (isDone) {
          ringColor = Colors.green;
          fillColor = Colors.green.withOpacity(0.18);
          textColor = Colors.white;
        } else if (isActive) {
          ringColor = _accent;
          fillColor = _accent.withOpacity(0.18);
          textColor = Colors.white;
        } else {
          ringColor = Colors.grey;
          fillColor = _card2;
          textColor = Colors.grey;
        }

        return Expanded(
          child: Row(
            children: [
              // Dot + Label
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: ringColor.withOpacity(0.55)),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check, size: 18, color: Colors.green)
                          : Text(
                              "${index + 1}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[index],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          isActive ? FontWeight.w800 : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              // Connector line
              if (index != 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: index < step ? _accent : _border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
