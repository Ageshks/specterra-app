import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../attendance/attendance_sheets.dart';
import '../attendance/overtime_history_screen.dart';
import '../billing/billing_screens.dart';
import '../jobs/company_calendar_screen.dart';
import '../transfer/transfer_history_screen.dart';
import '../leave/leave_application_screen.dart';
import '../expenses/expense_claims_screen.dart';
import '../notifications/staff_notifications_screen.dart';
import 'attendance_card.dart';
import 'dashboard_widgets.dart';

/// Employee home (spec §19, §22).
///
/// Order matters: attendance sits at the top because marking presence gates
/// field work, then today's jobs, then the shortcuts.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Ticks periodically so the live "working duration" stays honest.
  DateTime _now = DateTime.now();
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;
    final employee = data.employee;
    if (employee == null) return const SizedBox.shrink();

    final today = controller.todayRecord(_now);
    final todays = data.todayJobs;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          DashboardHeader(employee: employee, now: _now),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              18,
              AppTheme.gutter,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // §11 — attendance card is the first thing on the dashboard.
                AttendanceCard(record: today, now: _now),
                const SizedBox(height: 22),
                const SectionHeader(title: "Today's Work"),
                if (todays.isEmpty)
                  const NoJobsTodayCard()
                else
                  ...todays.map(
                    (job) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: DashboardJobRow(job: job),
                    ),
                  ),
                const SizedBox(height: 22),
                const SectionHeader(title: 'Quick Actions'),
                DashboardQuickActions(
                  onAttendance: () =>
                      showAttendanceSheet(context, record: today, now: _now),
                  onOvertime: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OvertimeHistoryScreen(),
                    ),
                  ),
                  onTransfers: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const TransferHistoryScreen(),
                    ),
                  ),
                  onLeave: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LeaveApplicationScreen(),
                    ),
                  ),
                  onExpenses: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ExpenseClaimsScreen(),
                    ),
                  ),
                  onBilling: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BillingHistoryScreen(),
                    ),
                  ),
                  onCalendar: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CompanyCalendarScreen(),
                    ),
                  ),
                  onNotifications: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StaffNotificationsScreen(),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const SectionHeader(title: 'Notifications'),
                DashboardNotifications(data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient header: employee name, ID, department and live clock (§19).
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.employee, required this.now});

  final Employee employee;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final unreadCount = AppScope.of(context).repository.unreadCount;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            14,
            AppTheme.gutter,
            22,
          ),
          child: Row(
            children: [
              StaffAvatar(
                initials: employee.initials,
                size: 46,
                background: Colors.white24,
                foreground: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hello, ${employee.firstName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${employee.employeeId} - ${employee.department}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () async {
                      await Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => const StaffNotificationsScreen(),
                        ),
                      );
                      if (context.mounted) {
                        await AppScope.read(context).refresh();
                      }
                    },
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            right: -7,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 17,
                                minHeight: 17,
                              ),
                              decoration: const BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.time(now),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
