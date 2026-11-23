import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/nested_navigator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../customer_app/core/theme/app_theme.dart' as customer_theme;
import '../../customer_app/features/auth/signup_screen.dart' as customer_signup;
import '../../customer_app/features/home/home_shell.dart' as customer_home;
import '../../customer_app/state/app_state.dart' as customer_state;
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/brand_mark.dart';
import 'password_recovery_screen.dart';
import '../manager/supervisor_shell.dart';
import '../shell/app_shell.dart';

/// Single login page for customers and field staff.
///
/// * `SPT-XXXX` style IDs sign in as staff via the offline demo accounts.
/// * Staff **emails** sign in against the live VPS (`POST /auth/login`) and
///   route by the returned role (manager / employee / customer).
/// * Customer emails sign in via the customer auth against the same endpoint.
/// * Registration always creates a **customer** account.
class UnifiedLoginScreen extends StatefulWidget {
  const UnifiedLoginScreen({super.key});

  static bool isStaffIdentifier(String value) {
    final text = value.trim().toUpperCase();
    if (text.isEmpty) return false;
    if (RegExp(r'^SPT[\s-]*\d+$').hasMatch(text)) return true;
    if (!text.contains('@') &&
        RegExp(r'^[A-Z]{2,6}[\s-]\d{2,6}$').hasMatch(text)) {
      return true;
    }
    return false;
  }

  @override
  State<UnifiedLoginScreen> createState() => _UnifiedLoginScreenState();
}

class _UnifiedLoginScreenState extends State<UnifiedLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  late final customer_state.AppController _customerController =
      customer_state.AppController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  /// Set once the customer controller is handed to a session/signup route,
  /// so this screen no longer disposes it.
  bool _handedOffCustomerController = false;

  bool get _isStaff => UnifiedLoginScreen.isStaffIdentifier(_identifier.text);

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    if (!_handedOffCustomerController) _customerController.dispose();
    super.dispose();
  }

  String? _validateIdentifier(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter email, phone number or employee ID';
    if (UnifiedLoginScreen.isStaffIdentifier(text)) return null;
    final isEmail = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text);
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (!isEmail && digits.length != 10) {
      return 'Enter valid email, 10 digit phone or ID like SPT-1042';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    if (value!.length < 4) return 'Password must be at least 4 characters';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_isStaff) {
        await _signInStaff();
      } else {
        await _signInCustomer();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInStaff() async {
    try {
      await AppScope.read(
        context,
      ).repositoryLogin(employeeId: _identifier.text, password: _password.text);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign you in. Please try again.');
      return;
    }
    if (!mounted) return;
    final employee = AppScope.read(context).data.employee;
    final role = (employee?.role ?? '').toLowerCase();
    // Live VPS returns roles like MANAGER / EMPLOYEE / ADMIN / CUSTOMER.
    if (role.contains('customer')) {
      setState(
        () => _error =
            'This account is a customer account. Please sign in as customer below.',
      );
      await AppScope.read(context).signOut();
      return;
    }
    final isManager = role.contains('manager') || role.contains('admin');
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => isManager ? const SupervisorShell() : const AppShell(),
      ),
      (route) => false,
    );
  }

  /// Tries staff login first for emails (the server holds all roles behind
  /// one login endpoint), then falls back to the customer flow.
  Future<void> _signInCustomer() async {
    final text = _identifier.text.trim();
    if (text.contains('@')) {
      try {
        await AppScope.read(
          context,
        ).repositoryLogin(employeeId: text, password: _password.text);
        if (!mounted) return;
        final employee = AppScope.read(context).data.employee;
        final role = (employee?.role ?? '').toLowerCase();
        if (role.contains('manager') ||
            role.contains('admin') ||
            role.contains('employee') ||
            role.contains('staff') ||
            role.contains('technician')) {
          final isManager = role.contains('manager') || role.contains('admin');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute<void>(
              builder: (_) =>
                  isManager ? const SupervisorShell() : const AppShell(),
            ),
            (route) => false,
          );
          return;
        }
        // Not a staff role -> sign out the staff session and continue below
        // as a customer.
        await AppScope.read(context).signOut();
      } on AuthException {
        // Bad credentials on staff attempt: still try the customer flow so
        // the server's own message surfaces below. Fall through.
      } catch (_) {
        // Unreachable server: the customer service has its own offline
        // fallback. Fall through.
      }
      if (!mounted) return;
    }
    final success = await _customerController.signIn(
      _identifier.text,
      _password.text,
    );
    if (!mounted) return;
    if (!success) {
      setState(
        () => _error =
            _customerController.authError ?? 'Unable to sign in right now.',
      );
      return;
    }
    _handedOffCustomerController = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSessionHost(
          controller: _customerController,
          keepAlive: true,
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _customerController.continueAsGuest();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    _handedOffCustomerController = true;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSessionHost(
          controller: _customerController,
          guestMode: true,
          keepAlive: true,
        ),
      ),
      (route) => false,
    );
  }

  void _openSignup() {
    _handedOffCustomerController = true;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerSignupHost(controller: _customerController),
      ),
    );
  }

  void _openForgotPassword() {
    final identifier = _identifier.text.trim();
    final initialEmail =
        RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(identifier)
        ? identifier
        : '';
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PasswordRecoveryScreen(initialEmail: initialEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            12,
            AppTheme.gutter,
            28,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: BrandMark(height: BrandConfig.authMarkHeight),
                ),
                const SizedBox(height: 18),
                Text(
                  'Welcome to SPECTERRA',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Sign in with your customer account or staff ID.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _RoleHint(isStaff: _isStaff),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Email, phone or Employee ID',
                    hintText: 'you@example.com / 98765 43210 / SPT-1042',
                    prefixIcon: Icon(
                      _isStaff
                          ? Icons.badge_outlined
                          : Icons.person_outline_rounded,
                    ),
                  ),
                  validator: _validateIdentifier,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy ? null : _openForgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 14),
                ],
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Sign In'),
                ),

                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                  ),
                  child: const Text('Continue as Guest'),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    const Text(
                      'New to SPECTERRA? ',
                      style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                    ),
                    GestureDetector(
                      onTap: _busy ? null : _openSignup,
                      child: const Text(
                        'Create a customer account',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleHint extends StatelessWidget {
  const _RoleHint({required this.isStaff});
  final bool isStaff;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isStaff ? AppColors.infoSoft : AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            isStaff ? Icons.badge_outlined : Icons.person_outline_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isStaff
                  ? 'Employee ID detected — signing in as field staff.'
                  : 'Signing in as a customer. New accounts are customers.',
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hosts signed-in / guest customer UI with an existing controller.
class CustomerSessionHost extends StatefulWidget {
  const CustomerSessionHost({
    super.key,
    required this.controller,
    this.guestMode = false,
    this.keepAlive = false,
  });
  final customer_state.AppController controller;
  final bool guestMode;
  final bool keepAlive;
  @override
  State<CustomerSessionHost> createState() => _CustomerSessionHostState();
}

class _CustomerSessionHostState extends State<CustomerSessionHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCustomerAuthChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCustomerAuthChanged);
    if (!widget.keepAlive) widget.controller.dispose();
    super.dispose();
  }

  void _onCustomerAuthChanged() {
    if (!mounted) return;
    // Customer signed out -> drop back to the single unified login.
    if (!widget.controller.isAuthenticated &&
        widget.controller.status == customer_state.AuthStatus.unauthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const UnifiedLoginScreen()),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: customer_theme.AppTheme.light,
      child: customer_state.CustomerScope(
        controller: widget.controller,
        // A nested navigator keeps every route pushed from the shell (booking
        // wizard, service details, tracking, ...) below the CustomerScope so
        // those screens can resolve CustomerScope.of(context). Pushes on the
        // root navigator would build outside the scope and crash.
        // NestedNavigator additionally forwards the system back button and
        // gesture to this navigator, so back pops the pushed route instead of
        // closing the app (the root host route is first and would bubble).
        child: NestedNavigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) =>
                customer_home.HomeShell(guestMode: widget.guestMode),
          ),
        ),
      ),
    );
  }
}

/// Wraps customer-only signup; created accounts are customers by design.
class CustomerSignupHost extends StatefulWidget {
  const CustomerSignupHost({super.key, required this.controller});
  final customer_state.AppController controller;
  @override
  State<CustomerSignupHost> createState() => _CustomerSignupHostState();
}

class _CustomerSignupHostState extends State<CustomerSignupHost> {
  bool _navigated = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_navigated || !mounted) return;
    if (widget.controller.isAuthenticated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => CustomerSessionHost(
              controller: widget.controller,
              keepAlive: true,
            ),
          ),
          (route) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: customer_theme.AppTheme.light,
      child: customer_state.CustomerScope(
        controller: widget.controller,
        child: NestedNavigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const customer_signup.SignUpScreen(),
          ),
        ),
      ),
    );
  }
}
