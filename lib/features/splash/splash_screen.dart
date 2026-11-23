import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../customer_app/state/app_state.dart' as customer_state;
import '../../widgets/brand_mark.dart';
import '../../state/app_controller.dart';
import '../auth/unified_login_screen.dart';
import '../manager/supervisor_shell.dart';
import '../shell/app_shell.dart';

/// Branded splash that restores any persisted session, then routes
/// (spec §22).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    final controller = AppScope.read(context);
    // 1) A persisted staff session resumes straight into the right shell.
    final restoredStaff = await controller.restoreSession();
    if (!mounted) return;
    if (restoredStaff) {
      final role = (controller.data.employee?.role ?? '').toLowerCase();
      final isManager = role.contains('manager') || role.contains('admin');
      Navigator.of(context).pushReplacement(
        _route(isManager ? const SupervisorShell() : const AppShell()),
      );
      return;
    }
    // 2) A persisted customer session resumes into the customer app.
    final customerController = customer_state.AppController();
    final restoredCustomer = await customerController.restoreSession();
    if (!mounted) {
      customerController.dispose();
      return;
    }
    if (restoredCustomer) {
      Navigator.of(context).pushReplacement(
        _route(
          CustomerSessionHost(controller: customerController, keepAlive: true),
        ),
      );
      return;
    }
    // 3) Nothing persisted — straight to the unified login screen. It also
    // offers "Continue as Guest", so guest booking stays one tap away.
    customerController.dispose();
    Navigator.of(context).pushReplacement(_route(const UnifiedLoginScreen()));
  }

  /// The unified entry lets customers continue as guests and routes staff by role.
  Route<void> _route(Widget page) {
    return MaterialPageRoute<void>(builder: (_) => page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forestDeep,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reuses the shared brand lockup at staff-app scale.
                const BrandLockup(
                  markSize: BrandConfig.splashLogoWidth * 0.34,
                  color: Colors.white,
                  captionColor: Colors.white70,
                ),
                const SizedBox(height: 28),
                const Text(
                  'WATER CARE, MADE SIMPLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 40),
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
