import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

/// Employee overtime eligibility, active-shift application, and own history.
class OvertimeHistoryScreen extends StatefulWidget {
  const OvertimeHistoryScreen({
    super.key,
    this.showAutoCheckoutNotice = false,
    this.showReminderNotice = false,
  });

  final bool showAutoCheckoutNotice;
  final bool showReminderNotice;

  @override
  State<OvertimeHistoryScreen> createState() => _OvertimeHistoryScreenState();
}

class _OvertimeHistoryScreenState extends State<OvertimeHistoryScreen> {
  OvertimeEligibility? _eligibility;
  AttendanceRecord? _todayAttendance;
  List<OvertimeEntry> _entries = const [];
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = AppScope.read(context).repository;
    final eligibilityRequest = repository.fetchOvertimeEligibility();
    final attendanceRequest = repository.fetchToday();
    final historyRequest = repository.fetchOvertime();
    try {
      final eligibility = await eligibilityRequest;
      if (mounted) setState(() => _eligibility = eligibility);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    try {
      final attendance = await attendanceRequest;
      if (mounted) setState(() => _todayAttendance = attendance);
    } catch (_) {}
    // A history outage should not prevent overtime eligibility or attendance
    // details from being displayed.
    try {
      final entries = await historyRequest;
      if (mounted)
        setState(() {
          _entries = entries;
          _historyError = null;
        });
    } catch (error) {
      if (mounted) setState(() => _historyError = error.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _apply() async {
    final eligibility = _eligibility;
    if (eligibility == null ||
        !eligibility.canApply ||
        eligibility.existingRequest != null)
      return;
    final reason = TextEditingController();
    final autoCheckedOut = _todayAttendance?.isAutoCheckedOut == true;
    final duration = TextEditingController(text: '60');
    var breakMinutes = 0;
    final formKey = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Apply for overtime'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (autoCheckedOut) ...[
                  TextFormField(
                    controller: duration,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Overtime worked (minutes)',
                      hintText: 'For example, 60',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final minutes = int.tryParse(value?.trim() ?? '');
                      if (minutes == null || minutes < 1) {
                        return 'Enter a duration in minutes.';
                      }
                      return minutes > 720
                          ? 'Maximum duration is 720 minutes.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: reason,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter a reason.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: breakMinutes,
                  decoration: const InputDecoration(
                    labelText: 'Break taken',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('No break')),
                    DropdownMenuItem(value: 60, child: Text('60 minutes')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => breakMinutes = value ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate())
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) {
      reason.dispose();
      duration.dispose();
      return;
    }
    setState(() => _submitting = true);
    final result = await AppScope.read(context).repository.requestOvertime(
      date: eligibility.date,
      requestedMinutes: autoCheckedOut ? int.parse(duration.text.trim()) : null,
      reason: reason.text,
      breakMinutes: breakMinutes,
    );
    reason.dispose();
    duration.dispose();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result case Failure<OvertimeEntry>(:final message)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Overtime request submitted.')),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Overtime'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  14,
                  AppTheme.gutter,
                  24,
                ),
                children: [
                  if (widget.showReminderNotice) ...[
                    const _OvertimeReminderNotice(),
                    const SizedBox(height: 12),
                  ],
                  if (widget.showAutoCheckoutNotice ||
                      _todayAttendance?.isAutoCheckedOut == true)
                    _AutoCheckoutNotice(attendance: _todayAttendance),
                  _eligibilityCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'OVERTIME HISTORY',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_historyError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Could not load overtime history: $_historyError',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (_entries.isEmpty)
                    const EmptyState(
                      icon: Icons.more_time_rounded,
                      title: 'No overtime requests',
                      message: 'Your submitted requests will appear here.',
                    )
                  else
                    for (final entry in _entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _OvertimeRow(entry: entry),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _eligibilityCard() {
    final eligibility = _eligibility;
    if (eligibility == null) {
      return AppCard(
        child: Text(
          _error ??
              'Overtime eligibility is currently unavailable. Pull to refresh.',
          style: const TextStyle(color: AppColors.danger),
        ),
      );
    }
    final request = eligibility.existingRequest;
    final allowApply = eligibility.canApply && request == null;
    final details = !eligibility.hasOngoingWork
        ? 'No ongoing work assignment was found for this shift.'
        : eligibility.canApply
        ? 'You have ongoing work and can apply for overtime.'
        : eligibility.eligibleAt != null &&
              DateTime.now().isBefore(eligibility.eligibleAt!)
        ? 'Overtime application opens at ${TimeOfDay.fromDateTime(eligibility.eligibleAt!.toLocal()).format(context)}.'
        : 'You are not currently eligible to apply.';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TODAY’S SHIFT',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            details,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (eligibility.checkInTime != null) ...[
            const SizedBox(height: 6),
            Text(
              'Checked in ${TimeOfDay.fromDateTime(eligibility.checkInTime!.toLocal()).format(context)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
          if (request != null) ...[
            const SizedBox(height: 12),
            _StatusPill(request.status),
            if (request.reason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(request.reason),
              ),
          ] else if (allowApply) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _submitting ? null : _apply,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: Text(_submitting ? 'Submitting…' : 'Apply for overtime'),
            ),
          ],
        ],
      ),
    );
  }
}

class _OvertimeReminderNotice extends StatelessWidget {
  const _OvertimeReminderNotice();

  @override
  Widget build(BuildContext context) => AppCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.notifications_active_outlined,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Your 8 hours 30 minutes shift, including the 1-hour break, ends in 10 minutes. '
            'Finish active work before then. If work will continue past shift end, '
            'submit an overtime request here when the server confirms you are eligible.',
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AutoCheckoutNotice extends StatelessWidget {
  const _AutoCheckoutNotice({this.attendance});
  final AttendanceRecord? attendance;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.schedule_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Automatically checked out',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  attendance?.checkOut != null
                      ? 'Your attendance was checked out after eight hours at ${TimeOfDay.fromDateTime(attendance!.checkOut!.toLocal()).format(context)}. ${attendance?.workingMinutes ?? 480} working minutes were recorded.'
                      : 'Your attendance was automatically checked out after eight hours. Open overtime below to request approval for work that remains.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OvertimeRow extends StatelessWidget {
  const _OvertimeRow({required this.entry});
  final OvertimeEntry entry;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                Formatters.dayMonthYear(entry.date),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _StatusPill(entry.status),
          ],
        ),
        if (entry.reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              entry.reason,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        if (entry.requestedMinutes > 0)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text('Planned overtime: ${entry.requestedMinutes} minutes'),
          ),
        if (entry.remarks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              'Review: ${entry.remarks}',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        if (entry.hours > 0)
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text('Requested ${Formatters.hoursMinutes(entry.hours)}'),
          ),
      ],
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);
  final String status;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.backgroundAlt,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Text(
      status.replaceAll('_', ' '),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
  );
}
