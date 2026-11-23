/// Date and number helpers shared across the app.
abstract final class Formatters {
  static DateTime inIndia(DateTime date) =>
      date.toUtc().add(const Duration(hours: 5, minutes: 30));

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static String dayMonth(DateTime date) =>
      '${date.day} ${_months[date.month - 1]}';

  static String weekday(DateTime date) => _weekdays[date.weekday - 1];

  /// Three letter weekday, e.g. `Mon`.
  static String weekdayShort(DateTime date) => weekday(date).substring(0, 3);

  /// `12 Jan 2026` style long form.
  static String fullDate(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';

  /// True when both timestamps fall on the same calendar day.
  static bool isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  static String shortDate(DateTime date) => '${dayMonth(date)}, ${date.year}';

  static String mediumDate(DateTime date) => '${dayMonth(date)} ${date.year}';

  static String longDate(DateTime date) =>
      '${weekday(date)}, ${date.day} ${_months[date.month - 1]} ${date.year}';

  /// 12 hour clock time, e.g. `10:30 AM`.
  static String time(DateTime date) {
    final ist = inIndia(date);
    final hour = ist.hour % 12 == 0 ? 12 : ist.hour % 12;
    final minute = ist.minute.toString().padLeft(2, '0');
    final suffix = ist.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }

  static String dateTime(DateTime date) {
    final ist = inIndia(date);
    return '${shortDate(ist)}, ${time(date)}';
  }

  /// Thousands separated amount, e.g. `₹12,450`.
  static String rupees(int amount) => '₹${_grouped(amount)}';

  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  /// Compact relative label such as `in 2 days` or `3 days ago`.
  static String relativeDay(DateTime date, {DateTime? from}) {
    final now = from ?? DateTime.now();
    final target = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final days = target.difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    if (days == -1) return 'Yesterday';
    if (days > 0) return 'in $days days';
    return '${days.abs()} days ago';
  }

  /// Formats a decimal hour count as `09h 33m`, the format spec §16–§18 use
  /// for working hours and overtime.
  static String hoursMinutes(double hours) {
    if (hours <= 0) return '00h 00m';
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}h '
        '${m.toString().padLeft(2, '0')}m';
  }

  /// Day-only identity, useful for grouping attendance records.
  static DateTime dayOf(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// `01 Oct 2026` style, as used throughout the attendance screens.
  static String dayMonthYear(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';

  /// `October 2026`, used as the monthly attendance heading (§17).
  static String monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';
}
