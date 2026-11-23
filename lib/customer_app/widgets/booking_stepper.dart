import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Four step progress indicator matching the booking reference artwork:
/// Service → Date & Time → Details → Confirm.
class BookingStepper extends StatelessWidget {
  const BookingStepper({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  final int currentStep;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        18,
        AppTheme.gutter,
        18,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List<Widget>.generate(steps.length, (index) {
          final isDone = index < currentStep;
          final isActive = index == currentStep;
          final color = isDone || isActive
              ? AppColors.primary
              : AppColors.backgroundAlt;

          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: (isDone || isActive)
                            ? null
                            : Border.all(color: AppColors.border, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : Text(
                              '${index + 1}',
                              style: textTheme.titleSmall?.copyWith(
                                color: isActive
                                    ? Colors.white
                                    : AppColors.muted,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ],
                ),
                if (index < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 14,
                      ),
                      color: isDone ? AppColors.primary : AppColors.border,
                    ),
                  )
                else
                  const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Step labels rendered under the circles, aligned per column.
class BookingStepLabels extends StatelessWidget {
  const BookingStepLabels({
    super.key,
    required this.currentStep,
    required this.steps,
  });

  final int currentStep;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: List<Widget>.generate(steps.length, (index) {
        final isActive = index <= currentStep;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              steps[index],
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: isActive ? AppColors.primary : AppColors.muted,
                fontWeight: index == currentStep
                    ? FontWeight.w700
                    : FontWeight.w500,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }),
    );
  }
}
