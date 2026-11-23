import 'package:flutter/material.dart';

import '../../state/app_state.dart';
import '../home/home_shell.dart';
import '../splash/splash_screen.dart';
import 'login_screen.dart';
import 'guest_welcome_screen.dart';

/// Decides what the user sees based on authentication status: splash while
/// booting, sign-in when anonymous, the customer shell once authenticated.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.showGuestWelcome = true});

  /// Shows the guest welcome before sign-in when true. The role chooser can
  /// set this false to open the customer login screen directly.
  final bool showGuestWelcome;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _bootstrapped = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      CustomerScope.of(context).bootstrap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final status = controller.status;

    final Widget child = switch (status) {
      AuthStatus.unknown => const SplashScreen(key: ValueKey('splash')),
      AuthStatus.unauthenticated ||
      AuthStatus.authenticating => widget.showGuestWelcome
          ? const GuestWelcomeScreen(key: ValueKey('welcome'))
          : const LoginScreen(key: ValueKey('login')),
      AuthStatus.authenticated => const HomeShell(key: ValueKey('shell')),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOut,
      child: child,
    );
  }
}
