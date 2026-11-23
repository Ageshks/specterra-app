import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'overtime_reminder_handler.dart';

typedef RegisterDeviceToken = Future<void> Function(String token);
typedef RemoveDeviceToken = Future<void> Function(String token);

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;
  OvertimeReminderHandler? _handler;
  RegisterDeviceToken? _registerToken;
  bool _initialized = false;
  bool _supported = false;
  String? _registeredToken;

  static const _channel = AndroidNotificationChannel(
    'general_notifications',
    'SPECTERRA updates',
    description: 'Work assignments, report decisions, and attendance updates.',
    importance: Importance.high,
  );

  Future<void> initialize({
    required OvertimeReminderAction onOvertimeReminder,
  }) async {
    _handler = OvertimeReminderHandler(onOpen: onOvertimeReminder);
    if (_initialized) return;
    _initialized = true;

    try {
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);
    } catch (error) {
      debugPrint('Local notifications could not initialize: $error');
    }

    if (Firebase.apps.isEmpty) {
      debugPrint(
        'Push notifications are disabled: Firebase is not configured. '
        'Add the Firebase platform configuration and initialize Firebase.',
      );
      return;
    }
    try {
      _supported = await _messaging.isSupported();
      if (!_supported) return;
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _onForegroundMessage,
        onError: (Object error) =>
            debugPrint('Foreground push listener failed: $error'),
      );
      _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _onRemoteNotificationTap,
        onError: (Object error) =>
            debugPrint('Push tap listener failed: $error'),
      );
      _tokenSubscription = _messaging.onTokenRefresh.listen(
        _registerRefreshedToken,
        onError: (Object error) =>
            debugPrint('Push token refresh listener failed: $error'),
      );
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        await _onRemoteNotificationTap(initialMessage);
      }
      final localLaunch = await _localNotifications
          .getNotificationAppLaunchDetails();
      final payload = localLaunch?.notificationResponse?.payload;
      if (localLaunch?.didNotificationLaunchApp == true && payload != null) {
        await _onLocalNotificationTap(
          NotificationResponse(
            id: localLaunch!.notificationResponse?.id,
            payload: payload,
            notificationResponseType:
                localLaunch.notificationResponse?.notificationResponseType ??
                NotificationResponseType.selectedNotification,
          ),
        );
      }
    } on FirebaseException catch (error) {
      debugPrint(
        'Push notifications could not initialize (${error.code}): '
        '${error.message ?? error.toString()}',
      );
    } catch (error) {
      debugPrint('Push notifications could not initialize: $error');
    }
  }

  Future<bool> registerAfterAuthentication({
    required RegisterDeviceToken registerToken,
  }) async {
    _registerToken = registerToken;
    if (!_supported) return false;
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('Push notifications are disabled by the user.');
        return false;
      }
      final token = await _messaging.getToken();
      if (token == null || token.trim().isEmpty) {
        debugPrint('Firebase did not provide a device token.');
        return false;
      }
      await _registerRefreshedToken(token);
      return true;
    } on FirebaseException catch (error) {
      debugPrint('Could not register push token (${error.code}): $error');
      return false;
    } catch (error) {
      debugPrint('Could not register push token: $error');
      return false;
    }
  }

  Future<void> unregisterOnLogout({
    required RemoveDeviceToken removeToken,
  }) async {
    final token = _registeredToken;
    if (token != null) {
      try {
        await removeToken(token);
      } catch (error) {
        debugPrint('Could not unregister push token on logout: $error');
      }
    }
    _registeredToken = null;
    _registerToken = null;
  }

  Future<void> _registerRefreshedToken(String token) async {
    if (token.isEmpty || token == _registeredToken) return;
    final register = _registerToken;
    if (register == null) return;
    try {
      await register(token);
      _registeredToken = token;
    } catch (error) {
      debugPrint('Could not register refreshed push token: $error');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    Future<void> showNotification() async {
      await _localNotifications.show(
        id: _notificationId(message.data, message.messageId),
        title: message.notification?.title ?? 'SPECTERRA update',
        body: message.notification?.body ?? 'You have a new update.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'general_notifications',
            'SPECTERRA updates',
            channelDescription:
                'Work assignments, report decisions, and attendance updates.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: jsonEncode(message.data),
      );
    }

    final handledAsReminder =
        await _handler?.handleForeground(
          data: message.data,
          eventId: message.messageId,
          showLocalNotification: showNotification,
        ) ??
        false;
    if (!handledAsReminder) await showNotification();
  }

  Future<void> _onRemoteNotificationTap(RemoteMessage message) =>
      _handleTap(message.data, message.messageId);

  Future<void> _onLocalNotificationTap(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        await _handleTap(decoded, response.id?.toString());
      }
    } on FormatException catch (error) {
      debugPrint('Ignoring invalid local notification payload: $error');
    }
  }

  Future<void> _handleTap(Map<String, dynamic> data, String? eventId) async {
    final handler = _handler;
    if (handler != null) {
      await handler.handleTap(data: data, eventId: eventId);
    }
  }

  int _notificationId(Map<String, dynamic> data, String? eventId) {
    final id =
        data['notificationId']?.toString() ??
        data['referenceId']?.toString() ??
        eventId ??
        'overtime-reminder';
    return id.hashCode & 0x7fffffff;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
