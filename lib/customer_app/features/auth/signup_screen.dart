import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_mark.dart';
import 'auth_widgets.dart';

/// Account creation screen with inline validation.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _acceptTerms = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _identifier.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    if (!_acceptTerms) {
      _showMessage('Please accept the terms to continue.');
      return;
    }
    final controller = CustomerScope.of(context);
    final success = await controller.signUp(
      name: _name.text,
      identifier: _identifier.text,
      password: _password.text,
      confirmPassword: _confirmPassword.text,
    );
    if (!success && mounted) {
      _showMessage(controller.authError ?? 'Unable to create account.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isBusy = CustomerScope.of(context).isBusy;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gutter,
            AppTheme.gutter,
            AppTheme.gutter,
            32,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: BrandMark(height: BrandConfig.authMarkHeight),
                ),
                const SizedBox(height: 20),
                Text(
                  "Let's get you started",
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Create an account to book and track your services',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Full Name',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) =>
                      (value ?? '').trim().split(RegExp(r'\s+')).length < 2
                      ? 'Enter your full name'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _identifier,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Email address',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) {
                      return 'Enter your email address';
                    }
                    final isEmail = RegExp(
                      r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                    ).hasMatch(text);
                    // Live register only accepts a real email.
                    if (!isEmail) return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    // Must match the live server rule: upper + lower + number.
                    if (text.length < 8) return 'Use at least 8 characters';
                    if (!RegExp(r'[A-Z]').hasMatch(text) ||
                        !RegExp(r'[a-z]').hasMatch(text) ||
                        !RegExp(r'[0-9]').hasMatch(text)) {
                      return 'Include upper, lower case and a number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPassword,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (value) =>
                      value != _password.text ? 'Passwords do not match' : null,
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _acceptTerms,
                  onChanged: (value) =>
                      setState(() => _acceptTerms = value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  title: Text(
                    'I agree to the Terms of Service and Privacy Policy',
                    style: textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: isBusy ? null : _submit,
                  child: isBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 18),
                AuthFooterLink(
                  message: 'Already have an account? ',
                  actionLabel: 'Login',
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
