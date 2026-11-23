typedef OvertimeReminderAction = Future<void> Function();

/// Validates overtime reminder data and deduplicates foreground display/taps.
class OvertimeReminderHandler {
  OvertimeReminderHandler({required this.onOpen});

  final OvertimeReminderAction onOpen;
  final Set<String> _displayed = <String>{};
  final Set<String> _opened = <String>{};

  bool isReminder(Map<String, dynamic> data) =>
      data['type']?.toString().toUpperCase() == 'OVERTIME_REMINDER' &&
      data['referenceType']?.toString().toLowerCase() ==
          'overtime_reminder';

  Future<bool> handleForeground({
    required Map<String, dynamic> data,
    required String? eventId,
    required Future<void> Function() showLocalNotification,
  }) async {
    if (!isReminder(data)) return false;
    final key = _key(data, eventId);
    if (key != null && !_displayed.add(key)) return false;
    await showLocalNotification();
    return true;
  }

  Future<bool> handleTap({
    required Map<String, dynamic> data,
    required String? eventId,
  }) async {
    if (!isReminder(data)) return false;
    final key = _key(data, eventId);
    if (key != null && !_opened.add(key)) return false;
    await onOpen();
    return true;
  }

  String? _key(Map<String, dynamic> data, String? eventId) {
    final notificationId = data['notificationId']?.toString().trim();
    if (notificationId != null && notificationId.isNotEmpty) {
      return 'notification:$notificationId';
    }
    final id = eventId?.trim();
    return id == null || id.isEmpty ? null : 'message:$id';
  }
}
