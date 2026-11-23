import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/brand_mark.dart';
import '../shell/app_shell.dart';
import '../manager/supervisor_shell.dart';
import 'password_recovery_screen.dart';

/// Employee login (spec §22). Authenticates on employee ID + password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeId = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _employeeId.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await AppScope.read(
        context,
      ).repositoryLogin(employeeId: _employeeId.text, password: _password.text);
      if (!mounted) return;
      final employee = AppScope.read(context).data.employee;
      final isManager =
          employee?.role.toLowerCase().contains('manager') ?? false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              isManager ? const SupervisorShell() : const AppShell(),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not sign you in. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            24,
            AppTheme.gutter,
            24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(
                  child: BrandMark(height: BrandConfig.authMarkHeight),
                ),
                const SizedBox(height: 20),
                Text(
                  'Employee Login',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in with the employee ID issued by your manager.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _employeeId,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Employee ID',
                    hintText: 'e.g. SPT-1042',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your employee ID'
                      : null,
                ),
                const SizedBox(height: 14),
                _passwordField(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PasswordRecoveryScreen(),
                            ),
                          ),
                    child: const Text('Forgot password? Use your email'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 22),
                _submitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return TextFormField(
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
          tooltip: _obscure ? 'Show password' : 'Hide password',
        ),
      ),
      validator: (value) =>
          (value == null || value.isEmpty) ? 'Enter your password' : null,
    );
  }

  Widget _submitButton() {
    return FilledButton(
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
