import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import 'models/customer.dart';

/// Raised when authentication calls fail validation.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Authentication against the SPECTERRA backend at [ApiConfig.baseUrl].
///
/// Live VPS endpoints (strict DTOs — no extra keys):
/// * `POST /auth/login` with `{ email, password }` — all roles
/// * `POST /auth/register` with `{ firstName, lastName, email, password }`
/// * `POST /auth/forgot-password` and `/auth/reset-password` for email OTP recovery
/// * `POST /auth/change-password` with the current password for signed-in users
/// * `POST /auth/refresh` with `{ refreshToken }`
/// * `GET /auth/me` for the current profile
///
/// Every call hits the backend directly — no offline fallback. Failures
/// throw [AuthFailure] with the server's own message so the UI can show it.
class AuthService {
  AuthService({
    this.latency = const Duration(milliseconds: 900),
    ApiClient? api,
  }) : _api = api ?? ApiClient();

  final Duration latency;
  final ApiClient _api;

  ApiClient get api => _api;

  static final RegExp _email = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  bool _isEmail(String value) => _email.hasMatch(value.trim());

  Future<CustomerAuthSession> signIn(String identifier, String password) async {
    final id = identifier.trim();
    // Live server only accepts email logins; phones can't authenticate.
    if (!_isEmail(id)) {
      throw const AuthFailure('Enter the email address you registered with.');
    }
    if (password.length < 6) {
      throw const AuthFailure('Password must be at least 6 characters.');
    }
    try {
      final raw = await _api.post(
        '/auth/login',
        body: {'email': id, 'password': password},
      );
      final session = CustomerAuthSession.fromLoginResponse(raw);
      if (session.token == null) {
        throw const AuthFailure('Login failed. Please try again.');
      }
      return session;
    } on AuthFailure {
      rethrow;
    } on ApiException catch (error) {
      // Backend rejected the credentials -> surface its message.
      if (error.statusCode != null) throw AuthFailure(error.message);
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  /// Splits "First Last" into the pair the register endpoint requires.
  static List<String> splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return [parts.first, parts.first];
    return [parts.first, parts.sublist(1).join(' ')];
  }

  Future<CustomerAuthSession> signUp({
    required String name,
    required String identifier,
    required String password,
    required String confirmPassword,
  }) async {
    final trimmedName = name.trim();
    final id = identifier.trim();
    if (trimmedName.split(RegExp(r'\s+')).length < 2) {
      throw const AuthFailure('Please enter your full name.');
    }
    final isEmail = _isEmail(id);
    // Live register requires a real email (phone-only signups are rejected
    // by the server with "email must be an email").
    if (!isEmail) {
      throw const AuthFailure('Enter a valid email address.');
    }
    if (password.length < 8) {
      throw const AuthFailure('Password must be at least 8 characters.');
    }
    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      throw const AuthFailure(
        'Password must include an uppercase letter, a lowercase letter and a number.',
      );
    }
    if (password != confirmPassword) {
      throw const AuthFailure('Passwords do not match.');
    }
    final names = splitName(trimmedName);
    try {
      final raw = await _api.post(
        '/auth/register',
        body: {
          'firstName': names[0],
          'lastName': names[1],
          // Server rejects unknown keys, so only send what it accepts.
          'email': id,
          'password': password,
        },
      );
      final session = CustomerAuthSession.fromLoginResponse(raw);
      // The live register endpoint returns the user with NO tokens, so
      // immediately log in to obtain a session.
      if (session.token == null) {
        final loginRaw = await _api.post(
          '/auth/login',
          body: {'email': id, 'password': password},
        );
        final loginSession = CustomerAuthSession.fromLoginResponse(loginRaw);
        if (loginSession.token == null) {
          throw const AuthFailure(
            'Account created. Please log in with your new credentials.',
          );
        }
        return loginSession;
      }
      return session;
    } on AuthFailure {
      rethrow;
    } on ApiException catch (error) {
      if (error.statusCode != null) throw AuthFailure(error.message);
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Future<void> sendResetLink(String identifier) async {
    final id = identifier.trim();
    if (!_isEmail(id)) {
      throw const AuthFailure('Enter the email address you registered with.');
    }
    try {
      await _api.post(ApiEndpoints.authForgotPassword, body: {'email': id});
      return;
    } on ApiException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.authResetPassword,
        body: {
          'email': email.trim().toLowerCase(),
          'otp': otp.trim(),
          'newPassword': newPassword,
        },
      );
    } on ApiException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.post(
        ApiEndpoints.authChangePassword,
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on ApiException catch (error) {
      throw AuthFailure(error.message);
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }
}

/// Result of a successful customer login / registration.
///
/// Carries the raw user payload plus the bearer token (when the backend
/// issued one) so controllers can hydrate state without a second round-trip.
/// The live register endpoint returns the user with NO tokens, so post-
/// register callers must log in afterwards to get a session.
class CustomerAuthSession {
  const CustomerAuthSession({
    this.user,
    this.token,
    this.refreshToken,
    this.raw,
  });

  const CustomerAuthSession.offline()
    : user = null,
      token = null,
      refreshToken = null,
      raw = null;

  final Map<String, dynamic>? user;
  final String? token;
  final String? refreshToken;
  final dynamic raw;

  bool get isOffline => token == null && user == null;

  factory CustomerAuthSession.fromLoginResponse(dynamic decoded) {
    final token = extractAuthToken(decoded);
    final refresh = extractRefreshToken(decoded);
    final Map<String, dynamic>? source = decoded is Map<String, dynamic>
        ? decoded
        : null;
    final Map<String, dynamic>? withToken = source == null || token == null
        ? source
        : {...source, 'token': token};
    final user = extractUserMap(withToken ?? decoded);
    return CustomerAuthSession(
      user: user,
      token: token,
      refreshToken: refresh,
      raw: decoded,
    );
  }
}
