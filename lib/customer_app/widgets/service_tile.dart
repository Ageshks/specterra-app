import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import 'common_widgets.dart';
import 'filter_widgets.dart';

/// Compact service row used on the services list and in booking pickers.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
    this.trailing,
    this.selected = false,
    this.priceLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool selected;
  final String? priceLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      borderColor: selected ? AppColors.primary : AppColors.border,
      color: selected ? AppColors.mintSoft : AppColors.surface,
      radius: AppTheme.radiusMd,
      child: Row(
        children: [
          IconTile(
            icon: icon,
            size: 46,
            iconSize: 22,
            background: selected ? Colors.white : AppColors.mintSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (priceLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    priceLabel!,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing ??
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: selected ? AppColors.primary : AppColors.hint,
              ),
        ],
      ),
    );
  }
}
