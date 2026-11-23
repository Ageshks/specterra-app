import 'formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';

/// Turns raw check-in/check-out times into the statuses and figures spec
/// §11, §15, §16 and §18 require.
///
/// Every threshold comes from [AttendancePolicy] so the rules stay in one
/// place and can be changed by product without touching the logic.
abstract final class AttendanceCalc {
  /// A fresh "nothing has happened today" record.
  static AttendanceRecord blankRecord(DateTime now) {
    return AttendanceRecord(
      id: 'att_${_key(now)}',
      date: Formatters.dayOf(now),
      status: AttendanceStatus.notCheckedIn,
    );
  }

  /// Builds the record produced by checking in at [checkIn].
  static AttendanceRecord checkIn(DateTime checkIn) {
    return AttendanceRecord(
      id: 'att_${_key(checkIn)}',
      date: Formatters.dayOf(checkIn),
      status: statusForCheckIn(checkIn),
      checkIn: checkIn,
    );
  }

  /// `Late` when the check-in falls outside the grace window, else `Present`
  /// (spec §15).
  static AttendanceStatus statusForCheckIn(DateTime checkIn) {
    final shiftStart = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      AttendancePolicy.shiftStartHour,
      AttendancePolicy.shiftStartMinute,
    );
    final graceEnd = shiftStart.add(
      const Duration(minutes: AttendancePolicy.lateGraceMinutes),
    );
    return checkIn.isAfter(graceEnd)
        ? AttendanceStatus.late
        : AttendanceStatus.present;
  }

  /// Builds the record produced by checking out at [checkOut].
  ///
  /// A very short day is downgraded to `Half Day`, otherwise the day settles
  /// on `Checked Out` (spec §15, §18).
  static AttendanceRecord checkOut({
    required AttendanceRecord record,
    required DateTime checkOut,
  }) {
    final start = record.checkIn;
    double worked = 0;
    if (start != null && checkOut.isAfter(start)) {
      worked = checkOut.difference(start).inMinutes / 60.0;
    }

    final status = worked < AttendancePolicy.halfDayThresholdHours
        ? AttendanceStatus.halfDay
        : AttendanceStatus.checkedOut;

    return record.copyWith(status: status, checkOut: checkOut);
  }

  /// Overtime for a finished day, driven by [AttendancePolicy.expectedHours].
  static double overtimeHours(AttendanceRecord record) =>
      record.overtimeHours();

  /// Records that fall inside the last [days] days, newest first.
  static List<AttendanceRecord> recent(
    List<AttendanceRecord> records, {
    int days = 30,
    DateTime? from,
  }) {
    final today = Formatters.dayOf(from ?? DateTime.now());
    final cutoff = today.subtract(Duration(days: days - 1));
    final filtered =
        records
            .where((r) => !r.date.isBefore(cutoff) && !r.date.isAfter(today))
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  /// Monday-based start of the week containing [reference].
  static DateTime startOfWeek(DateTime reference) {
    final day = Formatters.dayOf(reference);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// First and last day of the month containing [reference].
  static ({DateTime start, DateTime end}) monthRange(DateTime reference) {
    final start = DateTime(reference.year, reference.month, 1);
    final end = DateTime(reference.year, reference.month + 1, 0);
    return (start: start, end: end);
  }

  /// Records inside an inclusive range, newest first.
  static List<AttendanceRecord> inRange(
    List<AttendanceRecord> records, {
    required DateTime start,
    required DateTime end,
  }) {
    final from = Formatters.dayOf(start);
    final to = Formatters.dayOf(end);
    final filtered =
        records
            .where((record) {
              // API date fields are UTC midnight. Compare calendar days in
              // the same frame as the user-selected local date range.
              final day = Formatters.dayOf(record.date);
              return !day.isBefore(from) && !day.isAfter(to);
            })
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  /// Only days that actually recorded overtime.
  static List<AttendanceRecord> withOvertime(List<AttendanceRecord> records) {
    return records.where((r) => r.overtimeHours() > 0).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  static String _key(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}'
      '${date.day.toString().padLeft(2, '0')}';
}
