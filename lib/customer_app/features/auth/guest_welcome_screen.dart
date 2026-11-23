import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_mark.dart';
import '../home/home_shell.dart';
import 'login_screen.dart';
import '../tracking/guest_tracking_lookup_screen.dart';

/// Customer entry: booking is available to guests, with account access optional.
class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            children: [
              const Spacer(),
              const BrandMark(height: 72),
              const SizedBox(height: 24),
              Text('Water care, made simple', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Browse services and request a visit. You can book without an account.', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const Spacer(),
              SizedBox(width: double.infinity, child: FilledButton(
                onPressed: () async {
                  await CustomerScope.of(context).continueAsGuest();
                  if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const HomeShell(guestMode: true)));
                },
                child: const Text('Continue as Guest'),
              )),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: OutlinedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LoginScreen())),
                child: const Text('Login / Register'),
              )),
              TextButton.icon(
                onPressed: () async {
                  await CustomerScope.of(context).continueAsGuest();
                  if (!context.mounted) return;
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const GuestTrackingLookupScreen()));
                },
                icon: const Icon(Icons.track_changes_rounded),
                label: const Text('Track a Booking'),
              ),
              const SizedBox(height: 18),
              Text('SPECTERRA', style: TextStyle(color: colors.primary, fontWeight: FontWeight.w800, letterSpacing: 2)),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
