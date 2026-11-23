import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/attendance_calc.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/staff_widgets.dart';

/// Range filters offered by the history screen (spec §16).
enum AttendanceRange { thisWeek, thisMonth, custom }

extension on AttendanceRange {
  String get label => switch (this) {
    AttendanceRange.thisWeek => 'This Week',
    AttendanceRange.thisMonth => 'This Month',
    AttendanceRange.custom => 'Custom Date',
  };
}

/// "Attendance History" (spec §16).
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  AttendanceRange _range = AttendanceRange.thisMonth;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final records = _filter(data.attendance, DateTime.now());
    final total = records.fold<double>(0, (sum, r) => sum + r.overtimeHours());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Attendance History'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _FilterBar(
            range: _range,
            onChanged: (value) => setState(() => _range = value),
            onPickCustom: _pickCustom,
          ),
          Expanded(
            child: records.isEmpty
                ? const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No records',
                    message: 'There is no attendance in this period.',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.gutter,
                      4,
                      AppTheme.gutter,
                      24,
                    ),
                    itemCount: records.length + 1,
                    itemBuilder: (context, index) {
                      if (index == records.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Total overtime in this period: '
                            '${Formatters.hoursMinutes(total)}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: AttendanceRow(record: records[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<AttendanceRecord> _filter(List<AttendanceRecord> all, DateTime now) {
    return switch (_range) {
      AttendanceRange.thisWeek => AttendanceCalc.inRange(
        all,
        start: AttendanceCalc.startOfWeek(now),
        end: now,
      ),
      AttendanceRange.thisMonth => AttendanceCalc.inRange(
        all,
        start: AttendanceCalc.monthRange(now).start,
        end: AttendanceCalc.monthRange(now).end,
      ),
      AttendanceRange.custom =>
        _customFrom == null
            ? const <AttendanceRecord>[]
            : AttendanceCalc.inRange(
                all,
                start: _customFrom!,
                end: _customTo ?? _customFrom!,
              ),
    };
  }

  Future<void> _pickCustom() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 30)),
        end: DateTime.now(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _range = AttendanceRange.custom;
      _customFrom = picked.start;
      _customTo = picked.end;
    });
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.range,
    required this.onChanged,
    required this.onPickCustom,
  });

  final AttendanceRange range;
  final ValueChanged<AttendanceRange> onChanged;
  final VoidCallback onPickCustom;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        12,
      ),
      child: Row(
        children: [
          for (final option in AttendanceRange.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: option == AttendanceRange.custom ? 0 : 8,
                ),
                child: Material(
                  color: range == option
                      ? AppColors.primary
                      : AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: InkWell(
                    onTap: option == AttendanceRange.custom
                        ? onPickCustom
                        : () => onChanged(option),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: range == option
                              ? Colors.white
                              : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// §16 — one day: date, check-in, check-out, hours, overtime, status.
class AttendanceRow extends StatelessWidget {
  const AttendanceRow({super.key, required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;
    final overtime = record.overtimeHours();

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  Formatters.dayMonthYear(record.date),
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // §15 — status text is always present.
              StatusBadge.attendance(record.status, dense: true),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              AttendanceCell(label: 'Check-in', value: _time(checkIn)),
              AttendanceCell(label: 'Check-out', value: _time(checkOut)),
              AttendanceCell(
                label: 'Working Hours',
                value: Formatters.hoursMinutes(record.workedHours()),
              ),
              AttendanceCell(
                label: 'Overtime',
                value: Formatters.hoursMinutes(overtime),
                tint: overtime > 0 ? AppColors.warning : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _time(DateTime? value) =>
      value == null ? '--' : Formatters.time(value);
}

/// Shared labelled figure used by the history rows and overtime list.
class AttendanceCell extends StatelessWidget {
  const AttendanceCell({
    super.key,
    required this.label,
    required this.value,
    this.tint,
  });

  final String label;
  final String value;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tint ?? AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
