import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../jobs/job_details_screen.dart';

/// One work order in the "Today's Work" list (§19).
class DashboardJobRow extends StatelessWidget {
  const DashboardJobRow({super.key, required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JobDetailsScreen(jobId: job.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.work(job.status, dense: true),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            job.serviceType,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${Formatters.time(job.scheduledAt)} - '
                  '${Formatters.dayMonthYear(job.scheduledAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.priority(job.priority, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown when nothing is scheduled for today.
class NoJobsTodayCard extends StatelessWidget {
  const NoJobsTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              color: AppColors.hint,
              size: 30,
            ),
            SizedBox(height: 8),
            Text(
              'No work scheduled for today',
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashboard shortcuts for attendance, history, overtime and leave.
class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({
    super.key,
    required this.onAttendance,
    required this.onOvertime,
    required this.onTransfers,
    required this.onLeave,
    required this.onExpenses,
    required this.onBilling,
    required this.onCalendar,
    required this.onNotifications,
  });

  final VoidCallback onAttendance;
  final VoidCallback onOvertime;
  final VoidCallback onTransfers;
  final VoidCallback onLeave;
  final VoidCallback onExpenses;
  final VoidCallback onBilling;
  final VoidCallback onCalendar;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.event_available_rounded,
                label: 'Attendance',
                tint: AppColors.primary,
                onTap: onAttendance,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.more_time_rounded,
                label: 'Overtime',
                tint: AppColors.warning,
                onTap: onOvertime,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.swap_horiz_rounded,
                label: 'Transfer History',
                tint: AppColors.info,
                onTap: onTransfers,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.beach_access_rounded,
                label: 'Apply Leave',
                tint: AppColors.info,
                onTap: onLeave,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.receipt_long_rounded,
                label: 'Add Expense',
                tint: AppColors.primary,
                onTap: onExpenses,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.receipt_long_outlined,
                label: 'Billing History',
                tint: AppColors.primary,
                onTap: onBilling,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.calendar_month_outlined,
                label: 'Work Calendar',
                tint: AppColors.info,
                onTap: onCalendar,
              ),
            ),
            SizedBox(
              width: width,
              child: _ActionTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                tint: AppColors.warning,
                onTap: onNotifications,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Column(
            children: [
              Icon(icon, color: tint, size: 22),
              const SizedBox(height: 7),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §19 — new assignment, transfer update, manager instruction, report.
class DashboardNotifications extends StatelessWidget {
  const DashboardNotifications({super.key, required this.data});

  final AppData data;

  @override
  Widget build(BuildContext context) {
    final items = <_Note>[
      if (data.assignedJobs.isNotEmpty)
        _Note(
          icon: Icons.assignment_outlined,
          tint: AppColors.info,
          title: 'New assignment',
          body:
              '${data.assignedJobs.length} work order'
              '${data.assignedJobs.length == 1 ? '' : 's'} '
              'awaiting your acceptance.',
        ),
      if (data.pendingTransfers.isNotEmpty)
        _Note(
          icon: Icons.swap_horiz_rounded,
          tint: AppColors.warning,
          title: 'Transfer update',
          body:
              '${data.pendingTransfers.length} transfer request'
              '${data.pendingTransfers.length == 1 ? '' : 's'} '
              'awaiting manager approval.',
        ),
      if (data.myTransfers.isNotEmpty)
        _Note(
          icon: Icons.history_rounded,
          tint: AppColors.primaryLight,
          title: 'Transfer history',
          body: '${data.myTransfers.length} transfer request(s) raised by you.',
        ),
      const _Note(
        icon: Icons.sticky_note_2_outlined,
        tint: AppColors.primary,
        title: 'Manager instruction',
        body: 'Check the instructions on each job before you travel to site.',
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(items[i].icon, color: items[i].tint, size: 19),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].title,
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].body,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
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

class _Note {
  const _Note({
    required this.icon,
    required this.tint,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String body;
}
