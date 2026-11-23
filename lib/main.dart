import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/notifications/push_notification_service.dart';
import 'features/attendance/overtime_history_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/app_controller.dart';

final GlobalKey<NavigatorState> staffNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } on FirebaseException catch (error) {
    debugPrint(
      'Firebase is not configured; push reminders are unavailable '
      '(${error.code}): ${error.message ?? error.toString()}',
    );
  } catch (error) {
    debugPrint('Firebase initialization failed; push reminders unavailable: $error');
  }
  ErrorWidget.builder = (details) => _BrandedErrorWidget(
    message: details.exceptionAsString(),
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const StaffApp());
}

/// Keeps a failed widget from replacing a customer route with Flutter's solid
/// red debug surface, while leaving the underlying exception visible.
class _BrandedErrorWidget extends StatelessWidget {
  const _BrandedErrorWidget({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 36),
            const SizedBox(height: 12),
            const Text('This screen could not load', style: TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

/// Unified SPECTERRA app with customer, field staff and supervisor journeys.
class StaffApp extends StatefulWidget {
  const StaffApp({super.key});

  @override
  State<StaffApp> createState() => _StaffAppState();
}

class _StaffAppState extends State<StaffApp> {
  final AppController _controller = AppController();
  final PushNotificationService _pushNotifications = PushNotificationService();
  bool _pendingOvertimeReminder = false;
  bool _overtimeRouteOpen = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..onStaffAuthenticated = _afterStaffAuthenticated
      ..beforeStaffSignOut = () => _pushNotifications.unregisterOnLogout(
        removeToken: _controller.repository.removeDeviceToken,
      );
    unawaited(
      _pushNotifications.initialize(
        onOvertimeReminder: _openOvertimeReminder,
      ),
    );
  }

  Future<void> _afterStaffAuthenticated() async {
    await _pushNotifications.registerAfterAuthentication(
      registerToken: _controller.repository.registerDeviceToken,
    );
    if (_pendingOvertimeReminder) {
      _pendingOvertimeReminder = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushOvertimeScreen();
      });
    }
  }

  Future<void> _openOvertimeReminder() async {
    if (!_controller.data.isSignedIn) {
      _pendingOvertimeReminder = true;
      return;
    }
    _pushOvertimeScreen();
  }

  void _pushOvertimeScreen() {
    final navigator = staffNavigatorKey.currentState;
    if (navigator == null) {
      _pendingOvertimeReminder = true;
      return;
    }
    if (_overtimeRouteOpen) return;
    _overtimeRouteOpen = true;
    navigator
        .push(
          MaterialPageRoute<void>(
            builder: (_) => const OvertimeHistoryScreen(
              showReminderNotice: true,
            ),
          ),
        )
        .whenComplete(() => _overtimeRouteOpen = false);
  }

  @override
  void dispose() {
    unawaited(_pushNotifications.dispose());
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        navigatorKey: staffNavigatorKey,
        title: 'SPECTERRA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
