import 'package:flutter/material.dart';

import '../../../features/auth/password_recovery_screen.dart';

/// Compatibility route for callers that previously opened OTP verification.
class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key, required this.identifier});

  final String identifier;

  @override
  Widget build(BuildContext context) =>
      PasswordRecoveryScreen(initialEmail: identifier);
}
