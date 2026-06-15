import 'package:flutter/material.dart';

import '../../models/order_model.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class OrderTimeline extends StatelessWidget {
  final List<OrderTimelineStep> steps;

  const OrderTimeline({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepIndex = index ~/ 2;
          final isComplete = steps[stepIndex].isComplete;
          final nextComplete =
              stepIndex + 1 < steps.length && steps[stepIndex + 1].isComplete;
          return Expanded(
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: nextComplete ? AppColors.primary : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        } else {
          final step = steps[index ~/ 2];
          return _StepDot(step: step);
        }
      }),
    );
  }
}

class _StepDot extends StatelessWidget {
  final OrderTimelineStep step;

  const _StepDot({required this.step});

  @override
  Widget build(BuildContext context) {
    final isComplete = step.isComplete;

    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isComplete ? AppColors.primary : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isComplete ? AppColors.primary : Colors.grey.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: isComplete
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: Text(
            step.label,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: isComplete ? AppColors.primary : Colors.grey,
              fontSize: 8,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
