import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// The auth session recovered from disk after a cold start.
class PersistedSession {
  const PersistedSession({
    required this.token,
    this.refreshToken,
    required this.role,
    required this.isStaff,
  });

  final String token;
  final String? refreshToken;
  final String role;

  /// True when the session belongs to the staff surface (AppShell /
  /// SupervisorShell), false for the customer app.
  final bool isStaff;
}

/// Persists the signed-in session so killing the app does not log the user
/// out.
///
/// The bearer token still lives on `ApiClient` for the running process — this
/// store only mirrors it to `SharedPreferences` and hands it back on boot
/// ([StaffApp] restores via the splash screen).
///
/// All operations are serialised through an internal queue so an unawaited
/// [clear] (e.g. from a synchronous sign-out) can never overtake a later
/// [save]. Persistence is strictly best-effort: storage failures are swallowed
/// so a broken prefs plugin can never break the login flow — the worst case
/// is that the next launch shows the welcome screen again.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const String _tokenKey = 'specterra.session.token';
  static const String _refreshTokenKey = 'specterra.session.refreshToken';
  static const String _roleKey = 'specterra.session.role';
  static const String _isStaffKey = 'specterra.session.isStaff';

  /// Serialises reads/writes so an unawaited [clear] (e.g. from a
  /// synchronous sign-out) can never overtake a later [save].
  ///
  /// Implemented with a busy-flag + waiter queue instead of a chained future
  /// tail: a future created in one zone (e.g. a unit test's root zone) never
  /// propagates into another (the widget-test fake-async zone), which would
  /// stall every later caller. Only a bool and a list cross zone boundaries,
  /// so each caller's own futures stay in its own zone.
  bool _busy = false;
  final List<Future<void> Function()> _waiters = <Future<void> Function()>[];

  Future<T> _serialized<T>(Future<T> Function() action) {
    if (!_busy) return _drain(action);
    final completer = Completer<T>();
    _waiters.add(() async {
      try {
        completer.complete(await action());
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<T> _drain<T>(Future<T> Function() action) async {
    _busy = true;
    try {
      return await action();
    } finally {
      while (_waiters.isNotEmpty) {
        final next = _waiters.removeAt(0);
        await next();
      }
      _busy = false;
    }
  }

  /// Stores the session of a successful login. Called after the server
  /// issued a bearer token, never before.
  Future<void> save({
    required String token,
    String? refreshToken,
    String? role,
    required bool isStaff,
  }) {
    return _serialized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await prefs.setString(_refreshTokenKey, refreshToken);
        }
        await prefs.setString(_roleKey, role ?? '');
        await prefs.setBool(_isStaffKey, isStaff);
      } catch (_) {
        // Best-effort persistence — ignore storage failures.
      }
    });
  }

  /// Returns the persisted session, or null when the user is signed out (or
  /// storage is unavailable).
  Future<PersistedSession?> restore() {
    return _serialized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_tokenKey);
        if (token == null || token.isEmpty) return null;
        return PersistedSession(
          token: token,
          refreshToken: prefs.getString(_refreshTokenKey),
          role: prefs.getString(_roleKey) ?? '',
          isStaff: prefs.getBool(_isStaffKey) ?? false,
        );
      } catch (_) {
        return null;
      }
    });
  }

  /// Removes the persisted session (sign-out, or an expired token found
  /// during restore).
  Future<void> clear() {
    return _serialized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        await prefs.remove(_refreshTokenKey);
        await prefs.remove(_roleKey);
        await prefs.remove(_isStaffKey);
      } catch (_) {
        // Best-effort persistence — ignore storage failures.
      }
    });
  }

  /// Updates rotated credentials while preserving role and app scope.
  Future<void> updateTokens({required String token, String? refreshToken}) {
    return _serialized(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await prefs.setString(_refreshTokenKey, refreshToken);
        }
      } catch (_) {}
    });
  }
}
