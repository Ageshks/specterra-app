import 'package:flutter/material.dart';

import '../core/brand_config.dart';
import '../core/nested_navigator.dart';
import '../core/theme/app_theme.dart';
import '../customer_app/core/theme/app_theme.dart' as customer_theme;
import '../customer_app/features/home/home_shell.dart' as customer;
import '../customer_app/state/app_state.dart' as customer_state;
import '../widgets/brand_mark.dart';
import 'auth/unified_login_screen.dart';

class UnifiedHomeScreen extends StatelessWidget {
  const UnifiedHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            const SizedBox(height: 32),
            const Center(
              child: BrandMark(height: BrandConfig.authMarkHeight),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to SPECTERRA',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Book a service or sign in to your account.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 30),
            _RoleCard(
              title: 'Continue as Guest',
              detail: 'Browse services and book without an account',
              icon: Icons.water_drop_outlined,
              onTap: () => _openGuest(context),
            ),
            _RoleCard(
              title: 'Login',
              detail: 'One login for customers and field staff',
              icon: Icons.login_rounded,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UnifiedLoginScreen(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGuest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GuestLaunch(),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        leading:
            Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class GuestLaunch extends StatefulWidget {
  const GuestLaunch({super.key});
  @override
  State<GuestLaunch> createState() => _GuestLaunchState();
}

class _GuestLaunchState extends State<GuestLaunch> {
  late final customer_state.AppController _controller =
      customer_state.AppController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.continueAsGuest().then((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Theme(
      data: customer_theme.AppTheme.light,
      child: customer_state.CustomerScope(
        controller: _controller,
        // Nested navigator keeps pushed routes (booking wizard, service
        // details, sign-in shortcut) inside the CustomerScope, matching
        // CustomerSessionHost. NestedNavigator also forwards the system back
        // button / gesture to this navigator.
        child: NestedNavigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const customer.HomeShell(guestMode: true),
          ),
        ),
      ),
    );
  }
}

typedef LoginRoleScreen = UnifiedLoginScreen;
