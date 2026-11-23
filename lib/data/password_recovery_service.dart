import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';

/// Email OTP password recovery for every account type in the shared User table.
class PasswordRecoveryService {
  PasswordRecoveryService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Future<void> requestOtp(String email) async {
    await _api.post(
      ApiEndpoints.authForgotPassword,
      body: {'email': email.trim().toLowerCase()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.authResetPassword,
      body: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'newPassword': newPassword,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      ApiEndpoints.authChangePassword,
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }
}
