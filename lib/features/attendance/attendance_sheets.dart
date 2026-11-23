import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import 'attendance_result_screen.dart';

/// Opens the right attendance sheet for the current state.
///
/// One entry point keeps the dashboard card, the Attendance tab and any quick
/// action behaving identically (spec §10-§14).
Future<void> showAttendanceSheet(
  BuildContext context, {
  required AttendanceRecord record,
  required DateTime now,
}) {
  if (record.isCheckedOut) {
    return showAttendanceCompletedSheet(context, record: record);
  }
  if (record.isCheckedIn) {
    return showCheckOutSheet(context, record: record, now: now);
  }
  return showCheckInSheet(context, record: record, now: now);
}

/// Check-in confirmation (spec §12).
Future<void> showCheckInSheet(
  BuildContext context, {
  required AttendanceRecord record,
  required DateTime now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckInSheet(record: record, now: now),
  );
}

/// Checkout confirmation with the day's figures (spec §14).
Future<void> showCheckOutSheet(
  BuildContext context, {
  required AttendanceRecord record,
  required DateTime now,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CheckOutSheet(record: record, now: now),
  );
}

/// §13 — shown when a check-in is attempted on a day that already has one.
Future<void> showAttendanceAlreadySheet(
  BuildContext context, {
  required AttendanceRecord record,
  required DateTime now,
  String? reason,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AlreadySheet(record: record, now: now, reason: reason),
  );
}

/// Shown when the day is already closed (§14).
Future<void> showAttendanceCompletedSheet(
  BuildContext context, {
  required AttendanceRecord record,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CompletedSheet(record: record),
  );
}

/// §12 — "Ready to start your workday?" with the day's identity above it.
class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet({required this.record, required this.now});

  final AttendanceRecord record;
  final DateTime now;

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  bool _submitting = false;
  String? _error;

  Future<Position?> _captureCheckInLocation(BuildContext context) async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (!mounted || !context.mounted) return null;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Turn on location'),
          content: const Text(
            'Location is turned off. Enable Location Services in Settings to check in and record your attendance location.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) await Geolocator.openLocationSettings();
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (!mounted || !context.mounted) return null;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Location permission required'),
          content: const Text(
            'Allow location access in app settings to check in. Your location is captured only for attendance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open app settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) await Geolocator.openAppSettings();
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not get your current location. Turn on location and try again.',
        );
      }
      return null;
    }
  }

  Future<void> _mark(BuildContext context) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final controller = AppScope.read(context);
    final position = await _captureCheckInLocation(context);
    if (!mounted || !context.mounted) return;
    if (position == null) {
      setState(() => _submitting = false);
      return;
    }
    final result = await controller.checkIn(
      latitude: position.latitude,
      longitude: position.longitude,
    );
    if (!mounted || !context.mounted) return;

    // Keep API failures in the sheet so they remain visible to the employee.
    if (result is Failure<AttendanceRecord>) {
      final message = result.error ?? 'Could not mark attendance.';
      setState(() {
        _submitting = false;
        _error = message;
      });
      return;
    }

    final marked = (result as Success<AttendanceRecord>).value;
    final start = marked.checkIn;
    if (start == null) {
      setState(() {
        _submitting = false;
        _error = 'The server accepted check-in but returned no check-in time.';
      });
      return;
    }
    if (!mounted || !context.mounted) return;
    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceResultScreen(
          title: 'Attendance Marked Successfully',
          icon: Icons.check_circle_rounded,
          tint: AppColors.primary,
          rows: <({String label, String value})>[
            (label: 'Check-in Time', value: Formatters.time(start)),
            (label: 'Date', value: Formatters.dayMonthYear(marked.date)),
          ],
          ctaLabel: 'Return to Dashboard',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || AppScope.of(context).data.busy;
    final employee = AppScope.of(context).data.employee;

    return SheetShell(
      title: 'Check In',
      subtitle: _submitting
          ? 'Sending attendance to the server…'
          : 'Confirm the start of your workday.',
      children: [
        IdentityStrip(
          date: Formatters.dayMonthYear(widget.now),
          time: Formatters.time(widget.now),
          employeeId: employee?.employeeId ?? '',
        ),
        const SizedBox(height: 18),
        if (_error case final error?) ...[
          InfoCallout(
            icon: Icons.error_outline_rounded,
            message: error,
            tone: CalloutTone.danger,
          ),
          const SizedBox(height: 12),
        ],
        const InfoCallout(
          icon: Icons.waving_hand_rounded,
          message: 'Ready to start your workday?',
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'MARK ATTENDANCE / CHECK IN',
          icon: Icons.login_rounded,
          busy: busy,
          onPressed: () => _mark(context),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
      ],
    );
  }
}

/// §14 — "Are you sure you want to check out?" with the day's figures.
class _CheckOutSheet extends StatelessWidget {
  const _CheckOutSheet({required this.record, required this.now});

  final AttendanceRecord record;
  final DateTime now;

  Future<void> _confirm(BuildContext context) async {
    final result = await AppScope.read(context).checkOut();
    if (!context.mounted) return;

    if (result is Failure<AttendanceRecord>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }

    final updated = (result as Success<AttendanceRecord>).value;
    final start = updated.checkIn;
    final end = updated.checkOut;
    if (!context.mounted) return;

    Navigator.of(context).pop();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AttendanceResultScreen(
          title: 'Attendance Completed',
          icon: Icons.task_alt_rounded,
          tint: AppColors.primary,
          rows: <({String label, String value})>[
            (label: 'Check-in', value: Formatters.time(start!)),
            (label: 'Check-out', value: Formatters.time(end!)),
            (
              label: 'Total Working Hours',
              value: Formatters.hoursMinutes(updated.workedHours()),
            ),
            (
              label: 'Overtime',
              value: Formatters.hoursMinutes(updated.overtimeHours()),
            ),
          ],
          ctaLabel: 'Return to Dashboard',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).data.busy;
    final checkIn = record.checkIn;
    final worked = record.workedHours(now: now);
    final expected = record.expectedHours;
    final estimatedOvertime = (worked - expected).clamp(0.0, double.infinity);

    return SheetShell(
      title: 'Check Out',
      subtitle: 'End your working day.',
      children: [
        const InfoCallout(
          icon: Icons.help_outline_rounded,
          message: 'Are you sure you want to check out?',
          tone: CalloutTone.warning,
        ),
        const SizedBox(height: 16),
        SummaryGrid(
          rows: <({String label, String value, bool highlight})>[
            (
              label: 'Check-in Time',
              value: checkIn == null ? '--' : Formatters.time(checkIn),
              highlight: false,
            ),
            (
              label: 'Current Time',
              value: Formatters.time(now),
              highlight: false,
            ),
            (
              label: 'Working Duration',
              value: Formatters.hoursMinutes(worked),
              highlight: true,
            ),
            (
              label: 'Expected Working Hours',
              value: Formatters.hoursMinutes(expected),
              highlight: false,
            ),
            (
              label: 'Estimated Overtime',
              value: Formatters.hoursMinutes(estimatedOvertime),
              highlight: estimatedOvertime > 0,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'CANCEL',
                onPressed: busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PrimaryButton(
                label: 'CONFIRM CHECK OUT',
                icon: Icons.logout_rounded,
                busy: busy,
                onPressed: () => _confirm(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// §13 — no second check-in button is offered here, only a way onward.
class _AlreadySheet extends StatelessWidget {
  const _AlreadySheet({required this.record, required this.now, this.reason});

  final AttendanceRecord record;
  final DateTime now;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;

    return SheetShell(
      title: 'Already Checked In',
      subtitle: 'Your attendance is marked for today.',
      children: [
        const InfoCallout(
          icon: Icons.info_outline_rounded,
          message: 'Already Checked In',
        ),
        if (reason != null) ...[
          const SizedBox(height: 12),
          Text(
            reason!,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SummaryGrid(
          rows: <({String label, String value, bool highlight})>[
            (
              label: 'Check-in Time',
              value: checkIn == null ? '--' : Formatters.time(checkIn),
              highlight: false,
            ),
            (
              label: 'Current Working Duration',
              value: Formatters.hoursMinutes(record.workedHours(now: now)),
              highlight: true,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'VIEW ATTENDANCE',
          icon: Icons.event_available_rounded,
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }
}

/// Shown when the day is already closed (§14).
class _CompletedSheet extends StatelessWidget {
  const _CompletedSheet({required this.record});

  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final checkIn = record.checkIn;
    final checkOut = record.checkOut;
    final overtime = record.overtimeHours();

    return SheetShell(
      title: 'Attendance Completed',
      subtitle:
          'Your workday for ${Formatters.dayMonthYear(record.date)} is closed.',
      children: [
        SummaryGrid(
          rows: <({String label, String value, bool highlight})>[
            (
              label: 'Check-in',
              value: checkIn == null ? '--' : Formatters.time(checkIn),
              highlight: false,
            ),
            (
              label: 'Check-out',
              value: checkOut == null ? '--' : Formatters.time(checkOut),
              highlight: false,
            ),
            (
              label: 'Total Working Hours',
              value: Formatters.hoursMinutes(record.workedHours()),
              highlight: true,
            ),
            (
              label: 'Overtime',
              value: Formatters.hoursMinutes(overtime),
              highlight: overtime > 0,
            ),
          ],
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'CLOSE',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Shared chrome for the attendance bottom sheets.
class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: AppTheme.gutter,
        right: AppTheme.gutter,
        top: 10,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Date / time / employee ID block used on the check-in sheet (§12).
class IdentityStrip extends StatelessWidget {
  const IdentityStrip({
    super.key,
    required this.date,
    required this.time,
    required this.employeeId,
  });

  final String date;
  final String time;
  final String employeeId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm + 2),
      ),
      child: Row(
        children: [
          Expanded(
            child: _IdentityCell(label: "Today's Date", value: date),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _IdentityCell(label: 'Current Time', value: time),
          ),
          Container(width: 1, height: 34, color: AppColors.border),
          Expanded(
            child: _IdentityCell(label: 'Employee ID', value: employeeId),
          ),
        ],
      ),
    );
  }
}

class _IdentityCell extends StatelessWidget {
  const _IdentityCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
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
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
