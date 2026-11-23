import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';

/// Illustrated empty state with an optional call to action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(
              size: compact ? 64 : 88,
              color: AppColors.mintSoft,
              icon: icon,
              iconColor: AppColors.primary,
              iconSize: compact ? 28 : 38,
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 210,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state with a retry affordance.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Badge(
              size: compact ? 64 : 88,
              color: AppColors.dangerSoft,
              icon: Icons.cloud_off_rounded,
              iconColor: AppColors.danger,
              iconSize: compact ? 28 : 38,
            ),
            SizedBox(height: compact ? 14 : 20),
            Text(
              'Something went wrong',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 210,
                child: FilledButton.tonal(
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Success confirmation panel with a spring-in check badge.
class SuccessState extends StatelessWidget {
  const SuccessState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.check_rounded,
    this.color = AppColors.success,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: _Badge(
                size: 92,
                color: color.withValues(alpha: 0.12),
                icon: icon,
                iconColor: color,
                iconSize: 48,
              ),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.size,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.iconSize,
  });

  final double size;
  final Color color;
  final IconData icon;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}
