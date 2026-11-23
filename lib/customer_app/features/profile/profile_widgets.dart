import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../widgets/common_widgets.dart';

/// Membership banner shown at the top of the profile screen.
class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.name,
    required this.plan,
    required this.initials,
  });

  final String name;
  final String plan;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: textTheme.titleLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                StatusPill(
                  label: plan,
                  color: AppColors.forestDeep,
                  background: Colors.white,
                  icon: Icons.workspace_premium_rounded,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Label / value row used in the contact details card.
class ProfileInfoTile extends StatelessWidget {
  const ProfileInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.primary),
          const SizedBox(width: 12),
          SizedBox(width: 96, child: Text(label, style: textTheme.bodySmall)),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact statistic row in the account summary card.
class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textTheme.bodyMedium),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Saved address row on the profile screen.
class ProfileAddressCard extends StatelessWidget {
  const ProfileAddressCard({super.key, required this.address});

  final ServiceAddress address;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(address.icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(address.lines, style: textTheme.bodySmall),
              ],
            ),
          ),
          if (address.isDefault)
            const StatusPill(
              label: 'Default',
              color: AppColors.primary,
              dense: true,
            ),
        ],
      ),
    );
  }
}
