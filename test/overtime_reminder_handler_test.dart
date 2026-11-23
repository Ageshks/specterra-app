import 'package:flutter_test/flutter_test.dart';
import 'package:specterra_staff/core/notifications/overtime_reminder_handler.dart';

void main() {
  const reminderData = <String, dynamic>{
    'type': 'OVERTIME_REMINDER',
    'referenceType': 'overtime_reminder',
    'referenceId': 'attendance-1',
    'notificationId': 'notification-1',
  };

  test('foreground reminder shows one local notification', () async {
    var localNotifications = 0;
    var openedScreens = 0;
    final handler = OvertimeReminderHandler(
      onOpen: () async {
        openedScreens++;
      },
    );

    final handled = await handler.handleForeground(
      data: reminderData,
      eventId: 'message-1',
      showLocalNotification: () async {
        localNotifications++;
      },
    );
    final duplicate = await handler.handleForeground(
      data: reminderData,
      eventId: 'message-1',
      showLocalNotification: () async {
        localNotifications++;
      },
    );

    expect(handled, isTrue);
    expect(duplicate, isFalse);
    expect(localNotifications, 1);
    expect(openedScreens, 0);
  });

  test('background notification tap opens overtime screen once', () async {
    var openedScreens = 0;
    final handler = OvertimeReminderHandler(
      onOpen: () async {
        openedScreens++;
      },
    );

    expect(
      await handler.handleTap(data: reminderData, eventId: 'message-2'),
      isTrue,
    );
    expect(
      await handler.handleTap(data: reminderData, eventId: 'message-2'),
      isFalse,
    );
    expect(openedScreens, 1);
  });

  test('cold-start notification tap opens overtime screen', () async {
    var openedScreens = 0;
    final handler = OvertimeReminderHandler(
      onOpen: () async {
        openedScreens++;
      },
    );

    expect(
      await handler.handleTap(data: reminderData, eventId: 'message-3'),
      isTrue,
    );
    expect(openedScreens, 1);
  });

  test('does not infer reminder type from notification text', () async {
    var openedScreens = 0;
    final handler = OvertimeReminderHandler(
      onOpen: () async {
        openedScreens++;
      },
    );

    expect(
      await handler.handleTap(
        data: const <String, dynamic>{
          'title': 'Overtime reminder',
          'body': 'Your shift threshold is near.',
        },
        eventId: 'message-4',
      ),
      isFalse,
    );
    expect(openedScreens, 0);
  });
}
