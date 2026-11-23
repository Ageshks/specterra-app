import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/attendance_calc.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../dashboard/attendance_card.dart';
import 'attendance_history_screen.dart';

/// "Attendance" tab (spec §10, §19).
///
/// Leads with today's state and the check-in/check-out action, then the
/// monthly summary and overtime, then the route into full history.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _now = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;
    final today = controller.todayRecord(_now);

    final month = AttendanceCalc.monthRange(_now);
    final monthRecords = AttendanceCalc.inRange(
      data.attendance,
      start: month.start,
      end: month.end,
    );
    final summary = AttendanceSummary.fromRecords(monthRecords);
    final overtime = AttendanceCalc.withOvertime(monthRecords);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _now = DateTime.now());
          await controller.refresh();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            14,
            AppTheme.gutter,
            28,
          ),
          children: [
            AttendanceCard(record: today, now: _now),
            const SizedBox(height: 20),
            SectionHeader(
              title: Formatters.monthYear(_now),
              trailing: const Text(
                'This month',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // §17 — simple summary cards, no charts.
            MonthlySummaryGrid(summary: summary),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Overtime'),
            OvertimePreview(records: overtime),
            const SizedBox(height: 20),
            SecondaryButton(
              label: 'VIEW ATTENDANCE HISTORY',
              icon: Icons.history_rounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AttendanceHistoryScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// §17 — Working Days, Present, Absent, Leave, Late, Total Overtime.
class MonthlySummaryGrid extends StatelessWidget {
  const MonthlySummaryGrid({super.key, required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Working Days',
                value: '${summary.workingDays}',
                icon: Icons.calendar_month_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Present',
                value: '${summary.present}',
                color: AppColors.success,
                icon: Icons.check_circle_outline_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'Absent',
                value: '${summary.absent}',
                color: AppColors.danger,
                icon: Icons.person_off_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Leave',
                value: '${summary.leave}',
                color: AppColors.info,
                icon: Icons.beach_access_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                label: 'Late',
                value: '${summary.late}',
                color: AppColors.warning,
                icon: Icons.running_with_errors_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StatTile(
          label: 'Total Overtime',
          value: Formatters.hoursMinutes(summary.overtimeHours),
          color: AppColors.primary,
          icon: Icons.more_time_rounded,
        ),
      ],
    );
  }
}

/// §18 — recent overtime entries with the figures broken out.
class OvertimePreview extends StatelessWidget {
  const OvertimePreview({super.key, required this.records});

  final List<AttendanceRecord> records;

  static const int _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const AppCard(
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 18,
            ),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'No overtime recorded this month.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visible = records.take(_previewCount).toList();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                children: [
                  Expanded(child: _OvertimeLine(record: visible[i])),
                  const SizedBox(width: 8),
                  Text(
                    '+${Formatters.hoursMinutes(visible[i].overtimeHours())}',
                    style: const TextStyle(
                      color: AppColors.warning,
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

class _OvertimeLine extends StatelessWidget {
  const _OvertimeLine({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Formatters.dayMonthYear(record.date),
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${checkIn == null ? '--' : Formatters.time(checkIn)} - '
          '${checkOut == null ? '--' : Formatters.time(checkOut)} • '
          '${Formatters.hoursMinutes(record.workedHours())} total',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
