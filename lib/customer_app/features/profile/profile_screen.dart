import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/loading_views.dart';
import '../booking/booking_screen.dart';
import '../checkups/checkups_screen.dart';
import '../reports/reports_screen.dart';
import '../reports/service_reports_screen.dart';
import 'service_locations_screen.dart';
import 'profile_widgets.dart';
import '../../../features/auth/password_recovery_screen.dart';

/// Account hub: plan, contact details, saved addresses and preferences.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;
    final customer = data.customer;

    if (data.isLoadingData && customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const SkeletonList(itemCount: 4, itemHeight: 90),
      );
    }

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: EmptyState(
          icon: Icons.person_off_outlined,
          title: 'Profile unavailable',
          message: data.dataError ?? 'We could not load your profile.',
          actionLabel: 'Retry',
          onAction: controller.reload,
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final spend = data.bookings
        .where((b) => b.status == BookingStatus.completed)
        .fold<int>(0, (sum, booking) => sum + booking.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _confirmSignOut(context, controller),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          32,
        ),
        children: [
          PlanCard(
            name: customer.name,
            plan: customer.plan,
            initials: customer.initials,
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                ProfileInfoTile(
                  icon: Icons.person_outline_rounded,
                  label: 'Full name',
                  value: customer.name,
                ),
                ProfileInfoTile(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: customer.email,
                ),
                ProfileInfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: customer.phone,
                ),
                ProfileInfoTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'Member since',
                  value: customer.memberSince,
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                ProfileStatTile(
                  label: 'Bookings',
                  value: '${data.bookings.length}',
                ),
                const Divider(height: 1),
                ProfileStatTile(
                  label: 'Reports',
                  value: '${data.reports.length}',
                ),
                const Divider(height: 1),
                ProfileStatTile(
                  label: 'Total spend',
                  value: Formatters.rupees(spend),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text('Saved addresses', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          if (data.addresses.isEmpty)
            const InfoNote(
              icon: Icons.home_outlined,
              message: 'No saved addresses yet.',
            )
          else
            ...data.addresses.map(
              (address) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ProfileAddressCard(address: address),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ServiceLocationsScreen(),
                ),
              ),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Manage Service Locations'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ChangePasswordScreen(api: controller.authService.api),
                ),
              ),
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Change Password'),
            ),
          ),
          const SizedBox(height: 18),
          Text('Quick links', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          const _QuickLinks(),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'SPECTERRA - v1.0.0',
              style: textTheme.bodySmall?.copyWith(color: AppColors.hint),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to manage bookings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay signed in'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.signOut();
  }
}

/// Settings style list of shortcuts and the sign out action.
class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _MenuRow(
            icon: Icons.build_circle_outlined,
            label: 'Service reports',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ServiceReportsScreen(),
              ),
            ),
          ),
          _MenuRow(
            icon: Icons.insights_outlined,
            label: 'Water reports',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ReportsScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.science_outlined,
            label: 'Free checkups',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CheckupsScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.calendar_month_outlined,
            label: 'Book a service',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BookingScreen()),
            ),
          ),
          _MenuRow(
            icon: Icons.credit_card_rounded,
            label: 'Payment methods',
            onTap: () => _toast(context, 'Payment methods coming soon'),
          ),
          _MenuRow(
            icon: Icons.help_outline_rounded,
            label: 'Help & support',
            onTap: () => _toast(context, 'Support: 1800 123 4567'),
          ),
          _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Sign out',
            isLast: true,
            onTap: () => CustomerScope.of(context).signOut(),
          ),
        ],
      ),
    );
  }

  static void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: 46, endIndent: 12),
      ],
    );
  }
}
