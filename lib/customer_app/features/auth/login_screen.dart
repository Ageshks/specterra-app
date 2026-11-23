import 'package:flutter/material.dart';

import '../../core/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/brand_mark.dart';
import 'auth_widgets.dart';
import 'forgot_password_screen.dart';
import 'signup_screen.dart';

/// Welcome Back / Sign in screen matching the reference design.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final controller = CustomerScope.of(context);
    final success = await controller.signIn(
      _identifierController.text,
      _passwordController.text,
    );
    if (success && mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    if (!success && mounted) {
      final message = controller.authError ?? 'Unable to sign in right now.';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _validateIdentifier(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Enter your email address';
    // Live login only accepts the registered email (no phone login).
    final isEmail = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text);
    if (!isEmail) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Enter your password';
    if (value!.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isBusy = controller.isBusy;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.tileGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              AppTheme.gutter,
              AppTheme.gutter,
              AppTheme.gutter + 12,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: BrandMark(height: BrandConfig.authMarkHeight),
                  ),
                  const SizedBox(height: 22),
                  Text('Welcome Back', style: textTheme.displaySmall),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to continue',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _identifierController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Email or Phone Number',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: _validateIdentifier,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                        ),
                      ),
                    ),
                    validator: _validatePassword,
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) =>
                            setState(() => _rememberMe = value ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      Text('Remember me', style: textTheme.bodyMedium),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        ),
                        child: const Text('Forgot Password?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
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
                        : const Text('Login'),
                  ),
                  const SizedBox(height: 22),
                  const OrDivider(),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => _showMessage(
                            'Google sign-in is available in the release build.',
                          ),
                    icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 24),
                  AuthFooterLink(
                    message: "Don't have an account? ",
                    actionLabel: 'Sign Up',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SignUpScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
