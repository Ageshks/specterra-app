import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Filled call-to-action button used for the one correct action on a screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final background = danger ? AppColors.danger : AppColors.primary;
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.hint,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
      child: busy
          ? const SizedBox(
              width: 19,
              height: 19,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Outlined secondary action. Deliberately lower visual weight than
/// [PrimaryButton] so optional paths are never the obvious choice (§2, §21).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final color = tint ?? AppColors.inkSoft;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 7)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tone for [InfoCallout].
enum CalloutTone { neutral, warning, success, danger }

/// Highlighted message strip.
class InfoCallout extends StatelessWidget {
  const InfoCallout({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = CalloutTone.neutral,
  });

  final String message;
  final IconData icon;
  final CalloutTone tone;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      CalloutTone.neutral => (AppColors.infoSoft, AppColors.info),
      CalloutTone.warning => (AppColors.warningSoft, AppColors.warning),
      CalloutTone.success => (AppColors.successSoft, AppColors.success),
      CalloutTone.danger => (AppColors.dangerSoft, AppColors.danger),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label/value grid used by the checkout summary and transfer recap (§14, §5).
class SummaryGrid extends StatelessWidget {
  const SummaryGrid({super.key, required this.rows});

  final List<({String label, String value, bool highlight})> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rows[i].label,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    rows[i].value,
                    style: TextStyle(
                      color: rows[i].highlight
                          ? AppColors.primary
                          : AppColors.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
