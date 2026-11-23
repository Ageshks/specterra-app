import 'package:flutter/material.dart';

import '../../../features/auth/password_recovery_screen.dart';

/// Kept as the customer-auth route, backed by the shared User email OTP flow.
class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => const PasswordRecoveryScreen();
}
