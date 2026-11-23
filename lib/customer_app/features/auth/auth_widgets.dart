import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// "OR" separator used between the primary action and social sign-in.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key, this.label = 'OR'});

  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(color: AppColors.muted),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

/// Centered footer link such as "Don't have an account? Sign Up".
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onTap,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(message, style: textTheme.bodyMedium),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: textTheme.titleSmall?.copyWith(color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}
