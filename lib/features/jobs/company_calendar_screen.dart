import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

DateTime _todayInIndia() {
  final now = Formatters.inIndia(DateTime.now());
  return DateTime(now.year, now.month, now.day);
}

/// Read-only company calendar maintained by Admin and Super Admin users.
class CompanyCalendarScreen extends StatefulWidget {
  const CompanyCalendarScreen({super.key});

  @override
  State<CompanyCalendarScreen> createState() => _CompanyCalendarScreenState();
}

class _CompanyCalendarScreenState extends State<CompanyCalendarScreen> {
  DateTime _focusedMonth = _todayInIndia();
  DateTime _selectedDay = _todayInIndia();
  WorkingCalendar? _calendar;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  bool _didLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _loadCalendar(_focusedMonth.year);
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadCalendar(int year, {bool showLoading = true}) async {
    final requestId = ++_requestId;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _error = null;
        if (_calendar?.year != year) _calendar = null;
      });
    }
    try {
      final calendar = await AppScope.read(
        context,
      ).repository.fetchWorkingCalendar(year);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _calendar = calendar;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.statusCode == 404
            ? 'The company calendar is not available on the server yet.'
            : error.message;
      });
    } on AuthException catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Could not load the company calendar. Check your connection.';
      });
    }
  }

  void _moveMonth(int amount) {
    final month = DateTime(_focusedMonth.year, _focusedMonth.month + amount);
    final selectedDate = DateTime(
      month.year,
      month.month,
      _selectedDay.day
          .clamp(1, DateTime(month.year, month.month + 1, 0).day)
          .toInt(),
    );
    setState(() {
      _focusedMonth = month;
      _selectedDay = selectedDate;
    });
    if (month.year != _calendar?.year) {
      _loadCalendar(month.year);
    }
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _focusedMonth = DateTime(day.year, day.month);
    });
    if (day.year != _calendar?.year) _loadCalendar(day.year);
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _calendar;
    if (calendar == null && _loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Company Calendar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (calendar == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Company Calendar')),
        body: ErrorState(
          message: _error ?? 'The company calendar is unavailable.',
          onRetry: () => _loadCalendar(_focusedMonth.year),
        ),
      );
    }

    final dayInfo = calendar.dayInfo(_selectedDay);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Calendar'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Refresh calendar',
            onPressed: _loading
                ? null
                : () => _loadCalendar(_focusedMonth.year, showLoading: false),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadCalendar(_focusedMonth.year, showLoading: false),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            14,
            AppTheme.gutter,
            28,
          ),
          children: [
            AppCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Previous month',
                        onPressed: () => _moveMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _chooseYear,
                          child: Text(
                            Formatters.monthYear(_focusedMonth),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _selectDay(_todayInIndia()),
                        child: const Text('Today'),
                      ),
                      IconButton(
                        tooltip: 'Next month',
                        onPressed: () => _moveMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  if (_loading) const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 5),
                  Row(
                    children: const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                        .map(
                          (label) => Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  _monthGrid(calendar),
                  const SizedBox(height: 10),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 8,
                    children: [
                      _CalendarLegend(
                        color: AppColors.success,
                        label: 'Working',
                      ),
                      _CalendarLegend(
                        color: AppColors.muted,
                        label: 'Non-working',
                      ),
                      _CalendarLegend(
                        color: AppColors.warning,
                        label: 'Holiday',
                      ),
                      _CalendarLegend(color: AppColors.info, label: 'Event'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionHeader(
              title: Formatters.longDate(_selectedDay),
              trailing: Text(
                dayInfo.isWorkingDay ? 'Working day' : 'Non-working day',
                style: TextStyle(
                  color: dayInfo.isWorkingDay
                      ? AppColors.success
                      : AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _selectedDayCard(dayInfo),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseYear() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select a year',
    );
    if (chosen == null || !mounted) return;
    final date = DateTime(chosen.year, chosen.month, chosen.day);
    setState(() {
      _focusedMonth = DateTime(date.year, date.month);
      _selectedDay = date;
    });
    if (date.year != _calendar?.year) _loadCalendar(date.year);
  }

  Widget _monthGrid(WorkingCalendar calendar) {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final leadingDays = firstDay.weekday - 1;
    final cells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (context, index) {
        final number = index - leadingDays + 1;
        if (number < 1 || number > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(_focusedMonth.year, _focusedMonth.month, number);
        final info = calendar.dayInfo(date);
        final selected = _key(date) == _key(_selectedDay);
        final today = _key(date) == _key(_todayInIndia());
        final type = info.exception?.type;
        final fill = selected
            ? AppColors.primary
            : type == 'EVENT' || type == 'WORKING_DAY'
            ? AppColors.infoSoft
            : type == 'HOLIDAY'
            ? AppColors.warningSoft
            : info.isWorkingDay
            ? AppColors.mintSoft
            : AppColors.backgroundAlt;
        final markerColor = selected
            ? Colors.white
            : type == 'EVENT' || type == 'WORKING_DAY'
            ? AppColors.info
            : type == 'HOLIDAY'
            ? AppColors.warning
            : info.isWorkingDay
            ? AppColors.success
            : AppColors.muted;

        return Padding(
          padding: const EdgeInsets.all(2),
          child: Material(
            color: fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              side: BorderSide(
                color: today && !selected
                    ? AppColors.primary
                    : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              onTap: () => _selectDay(date),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$number',
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight: selected || today
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _selectedDayCard(CalendarDayInfo info) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarStatusRow(
            icon: info.isWorkingDay
                ? Icons.work_outline_rounded
                : Icons.event_busy_outlined,
            label: 'Company schedule',
            value: info.isWorkingDay ? 'Working day' : 'Non-working day',
          ),
          if (info.exception != null) ...[
            const Divider(height: 20),
            _CalendarStatusRow(
              icon: switch (info.exception!.type) {
                'HOLIDAY' => Icons.celebration_outlined,
                'WORKING_DAY' => Icons.admin_panel_settings_outlined,
                _ => Icons.event_outlined,
              },
              label: info.exception!.type.replaceAll('_', ' '),
              value: info.exception!.title,
            ),
            if (info.exception!.note?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  info.exception!.note!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CalendarStatusRow extends StatelessWidget {
  const _CalendarStatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 8, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(color: AppColors.muted, fontSize: 10.5),
      ),
    ],
  );
}
