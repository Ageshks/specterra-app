import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/action_widgets.dart';

/// Confirmation screen shown after check-in and check-out (spec §12, §14).
class AttendanceResultScreen extends StatelessWidget {
  const AttendanceResultScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.tint,
    required this.rows,
    required this.ctaLabel,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final List<({String label, String value})> rows;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: tint, size: 46),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 22),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                child: Column(
                  children: [
                    for (var i = 0; i < rows.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, color: AppColors.border),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rows[i].label,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              rows[i].value,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(
                label: ctaLabel,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
