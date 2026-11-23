import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/password_recovery_service.dart';
import '../../widgets/action_widgets.dart';

String? _emailError(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Enter your email address.';
  if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email)) {
    return 'Enter a valid email address.';
  }
  return null;
}

String? _newPasswordError(String value) {
  if (value.length < 8) return 'Use at least 8 characters.';
  if (value.length > 72) return 'Use no more than 72 characters.';
  if (!RegExp(r'[A-Z]').hasMatch(value) ||
      !RegExp(r'[a-z]').hasMatch(value) ||
      !RegExp(r'[0-9]').hasMatch(value)) {
    return 'Include an uppercase letter, a lowercase letter and a number.';
  }
  return null;
}

/// Two-step email OTP reset flow shared by staff and customer accounts.
class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _recovery = PasswordRecoveryService();
  bool _codeSent = false;
  bool _complete = false;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    if (_emailError(_email.text) != null) {
      setState(() => _error = _emailError(_email.text));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _recovery.requestOtp(_email.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _busy = false;
        _otp.clear();
        _password.clear();
        _confirmPassword.clear();
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the server. Check your connection and try again.';
          _busy = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _recovery.resetPassword(
        email: _email.text,
        otp: _otp.text,
        newPassword: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _complete = true;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the server. Check your connection and try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_complete ? 'Password Reset' : 'Reset Password'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.gutter),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _complete ? _successView() : _formView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formView() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.lock_reset_rounded,
          size: 54,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        Text(
          _codeSent ? 'Enter your reset code' : 'Forgot your password?',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _codeSent
              ? 'If an account exists for ${_email.text.trim()}, a six-digit code was sent. It expires in 10 minutes and allows up to five attempts.'
              : 'Enter the email address linked to your staff or customer account. We’ll email a reset code if the account exists.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        TextFormField(
          controller: _email,
          readOnly: _codeSent,
          keyboardType: TextInputType.emailAddress,
          textInputAction: _codeSent
              ? TextInputAction.next
              : TextInputAction.done,
          onFieldSubmitted: (_) {
            if (!_codeSent) _requestCode();
          },
          decoration: const InputDecoration(
            labelText: 'Email address',
            prefixIcon: Icon(Icons.alternate_email_rounded),
          ),
          validator: (value) => _emailError(value ?? ''),
        ),
        if (_codeSent) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _otp,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: '6-digit email code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
            validator: (value) => (value ?? '').length == 6
                ? null
                : 'Enter the 6-digit code from your email.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            maxLength: 72,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'New password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
            ),
            validator: (value) => _newPasswordError(value ?? ''),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassword,
            obscureText: !_showPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            decoration: const InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_outline_rounded),
            ),
            validator: (value) =>
                value == _password.text ? null : 'Passwords do not match.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _requestCode,
              child: const Text('Send a new code'),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          InfoCallout(message: _error!, tone: CalloutTone.danger),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : (_codeSent ? _resetPassword : _requestCode),
          child: _busy
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(_codeSent ? 'Reset Password' : 'Send Reset Code'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: const Text('Back to Login'),
        ),
      ],
    ),
  );

  Widget _successView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(
        Icons.check_circle_outline_rounded,
        size: 58,
        color: AppColors.success,
      ),
      const SizedBox(height: 16),
      const Text(
        'Password updated',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your password was reset. Sign in with your new password.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.muted),
      ),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Back to Login'),
      ),
    ],
  );
}

/// Authenticated password change, which always sends the current password.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await PasswordRecoveryService(
        api: widget.api,
      ).changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully.')),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _busy = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Could not reach the server. Check your connection and try again.';
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Change Password')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            const Text('Enter your current password, then choose a new one.'),
            const SizedBox(height: 18),
            TextFormField(
              controller: _current,
              obscureText: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Enter your current password.' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _next,
              obscureText: true,
              maxLength: 72,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: (value) => _newPasswordError(value ?? ''),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm new password',
              ),
              validator: (value) =>
                  value == _next.text ? null : 'Passwords do not match.',
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              InfoCallout(message: _error!, tone: CalloutTone.danger),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Change Password'),
            ),
          ],
        ),
      ),
    ),
  );
}
