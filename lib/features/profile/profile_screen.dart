import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../manager/manager_transfers_screen.dart';
import '../transfer/transfer_history_screen.dart';
import '../unified_home_screen.dart';
import '../auth/password_recovery_screen.dart';

/// "Profile" tab, plus the entry point to the manager approval queue (§7).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final employee = data.employee;
    if (employee == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          16,
          AppTheme.gutter,
          28,
        ),
        children: [
          _IdentityCard(employee: employee),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Employment'),
          _EmploymentCard(employee: employee),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Work Summary'),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Assigned',
                  value: '${data.assignedJobs.length}',
                  icon: Icons.assignment_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'In Progress',
                  value: '${data.activeJobs.length}',
                  color: AppColors.info,
                  icon: Icons.play_circle_outline_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StatTile(
                  label: 'Completed',
                  value: '${data.completedJobs.length}',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Tools'),
          _ToolsTile(
            pending: data.pendingTransfers.length,
            myTransfers: data.myTransfers.length,
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _Row(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              detail: 'Update your password with your current password',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangePasswordScreen(
                    api: AppScope.read(context).repository.api,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _Row(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              detail: 'Sign out of your staff account',
              onTap: () => _confirmSignOut(context),
            ),
          ),
          const SizedBox(height: 18),
          const InfoNote(
            message:
                'Assigned work cannot be rejected. If you cannot attend, '
                'transfer it to an available colleague with a reason.',
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'SPECTERRA Field Staff - v1.1.2',
              style: TextStyle(
                color: AppColors.hint,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Log out?'),
      content: const Text(
        'You will need to sign in again to access your staff account.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  await AppScope.read(context).signOut();
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute<void>(builder: (_) => const UnifiedHomeScreen()),
    (route) => false,
  );
}

/// Name, role and employee ID header.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          StaffAvatar(initials: employee.initials, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  employee.role,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  employee.employeeId,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmploymentCard extends StatelessWidget {
  const _EmploymentCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.apartment_rounded,
            label: 'Department',
            value: employee.department,
          ),
          DetailRow(
            icon: Icons.badge_outlined,
            label: 'Employee ID',
            value: employee.employeeId,
          ),
          DetailRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: employee.email,
          ),
          DetailRow(
            icon: Icons.phone_outlined,
            label: 'Phone',
            value: employee.phone,
          ),
          DetailRow(
            icon: Icons.event_outlined,
            label: 'Joined',
            value: employee.joiningDate,
          ),
        ],
      ),
    );
  }
}

class _ToolsTile extends StatelessWidget {
  const _ToolsTile({required this.pending, required this.myTransfers});

  final int pending;
  final int myTransfers;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          _Row(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer History',
            detail: '$myTransfers requests',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const TransferHistoryScreen(),
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _Row(
            icon: Icons.approval_outlined,
            label: 'Manager: Transfer Requests',
            detail: '$pending pending',
            highlight: pending > 0,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ManagerTransfersScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final tint = highlight ? AppColors.warning : AppColors.primary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: tint, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              detail,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.hint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
