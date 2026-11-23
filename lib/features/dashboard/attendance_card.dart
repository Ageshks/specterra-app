import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../attendance/attendance_sheets.dart';

/// "Today's Attendance" card at the top of the dashboard (spec §11).
///
/// Renders three states from the same widget:
///  * not checked in  -> status, current time, CHECK IN
///  * checked in      -> check-in time, live duration, CHECK OUT
///  * checked out     -> check-in/out, total hours and overtime
class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.record, required this.now});

  final AttendanceRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).data.busy;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      "Today's Attendance",
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    // §15 — status is always spelled out, never colour-only.
                    StatusBadge.attendance(record.status, dense: true),
                  ],
                ),
                const SizedBox(height: 14),
                _Metrics(record: record, now: now),
              ],
            ),
          ),
          _ActionBar(record: record, now: now, busy: busy),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.record, required this.now});

  final AttendanceRecord record;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;

    if (checkIn == null) {
      return _Row(
        children: [
          _Metric(label: 'Current Time', value: Formatters.time(now)),
          const _MetricDivider(),
          _Metric(label: 'Shift Starts', value: _shiftStartLabel),
        ],
      );
    }

    if (checkOut == null) {
      return _Row(
        children: [
          _Metric(label: 'Check-in Time', value: Formatters.time(checkIn)),
          const _MetricDivider(),
          _Metric(
            label: 'Working Duration',
            value: Formatters.hoursMinutes(record.workedHours(now: now)),
            highlight: true,
          ),
        ],
      );
    }

    final total = record.workedHours();
    final overtime = record.overtimeHours();
    return _Row(
      children: [
        _Metric(label: 'Check-in', value: Formatters.time(checkIn)),
        const _MetricDivider(),
        _Metric(label: 'Check-out', value: Formatters.time(checkOut)),
        const _MetricDivider(),
        _Metric(
          label: 'Total Hours',
          value: Formatters.hoursMinutes(total),
          highlight: true,
        ),
        const _MetricDivider(),
        _Metric(
          label: 'Overtime',
          value: Formatters.hoursMinutes(overtime),
          highlight: overtime > 0,
          highlightColor: AppColors.warning,
        ),
      ],
    );
  }

  static const String _shiftStartLabel = '09:00 AM';
}

class _Row extends StatelessWidget {
  const _Row({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const _MetricDivider(),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  const _MetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AppColors.border,
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
    this.highlightColor,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final tint = highlight
        ? (highlightColor ?? AppColors.primary)
        : AppColors.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            color: tint,
            fontSize: highlight ? 15 : 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// Single primary button for the card: CHECK IN or CHECK OUT.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.record,
    required this.now,
    required this.busy,
  });

  final AttendanceRecord record;
  final DateTime now;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    // §14 — once the day is closed there is no check-in button to offer.
    if (record.isCheckedOut) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: const BoxDecoration(
          color: AppColors.mintSoft,
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(AppTheme.radiusMd),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.primary,
              size: 17,
            ),
            SizedBox(width: 7),
            Text(
              'Attendance completed for today',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final isCheckedIn = record.isCheckedIn;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppTheme.radiusMd),
        ),
      ),
      child: TextButton(
        onPressed: busy
            ? null
            : () => showAttendanceSheet(context, record: record, now: now),
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(AppTheme.radiusMd),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 7),
            // Spec wording is uppercase for these two buttons.
            Text(
              isCheckedIn ? 'CHECK OUT' : 'CHECK IN',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
