import 'package:flutter/widgets.dart';

import '../../core/network/api_client.dart';
import '../../core/session_store.dart';
import '../data/auth_service.dart';
import '../data/models/booking.dart';
import '../data/models/customer.dart';
import '../data/models/supporting_models.dart';
import '../data/models/water_service.dart';
import '../data/specterra_repository.dart';
import 'app_data.dart';

export 'app_data.dart' show AppData, AuthStatus, DataFailure;

/// Application-wide controller. Deliberately a plain [ChangeNotifier] so the
/// project keeps only the dependencies declared in `pubspec.yaml`.
class AppController extends ChangeNotifier {
  AppController({SpecterraRepository? repository, AuthService? authService})
    : repository = repository ?? SpecterraRepository(),
      authService = authService ?? AuthService();

  final SpecterraRepository repository;
  final AuthService authService;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  String? _authError;
  String? get authError => _authError;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isBusy => _status == AuthStatus.authenticating;

  AppData _data = const AppData();
  AppData get data => _data;

  Customer? get customer => _data.customer;
  int get unreadNotificationCount => _data.unreadNotificationCount;

  Future<void> bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Opens the customer experience without creating an account.
  Future<void> continueAsGuest() async {
    _status = AuthStatus.authenticated;
    notifyListeners();
    await loadAll();
  }

  Future<bool> signIn(String identifier, String password) async {
    _status = AuthStatus.authenticating;
    _authError = null;
    notifyListeners();
    try {
      final session = await authService.signIn(identifier, password);
      // AuthService only returns when the server issued a real token.
      final token = session.token;
      if (token == null) {
        throw const AuthFailure('Login failed. Please try again.');
      }
      authService.api.setToken(token);
      authService.api.setRefreshToken(session.refreshToken);
      repository.useApiClient(authService.api);
      // Persist the session so a cold start resumes without a new login.
      await SessionStore.instance.save(
        token: token,
        refreshToken: session.refreshToken,
        role: (session.user?['role'] ?? '').toString(),
        isStaff: false,
      );
      if (session.user != null) {
        try {
          _data = _data.copyWith(customer: Customer.fromJson(session.user!));
        } catch (_) {
          // Payload didn't match the Customer shape; loadAll below will
          // fetch the profile from the repository instead.
        }
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      await loadAll();
      return true;
    } on AuthFailure catch (error) {
      _status = AuthStatus.unauthenticated;
      _authError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String identifier,
    required String password,
    required String confirmPassword,
  }) async {
    _status = AuthStatus.authenticating;
    _authError = null;
    notifyListeners();
    try {
      final session = await authService.signUp(
        name: name,
        identifier: identifier,
        password: password,
        confirmPassword: confirmPassword,
      );
      // AuthService auto-logs-in after register, so a token is always
      // present here when the backend accepted the account.
      final token = session.token;
      if (token == null) {
        throw const AuthFailure(
          'Account created. Please log in with your new credentials.',
        );
      }
      authService.api.setToken(token);
      authService.api.setRefreshToken(session.refreshToken);
      repository.useApiClient(authService.api);
      // Persist the session so a cold start resumes without a new login.
      await SessionStore.instance.save(
        token: token,
        refreshToken: session.refreshToken,
        role: (session.user?['role'] ?? '').toString(),
        isStaff: false,
      );
      if (session.user != null) {
        try {
          _data = _data.copyWith(customer: Customer.fromJson(session.user!));
        } catch (_) {
          // loadAll below fetches the profile instead.
        }
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      await loadAll();
      return true;
    } on AuthFailure catch (error) {
      _status = AuthStatus.unauthenticated;
      _authError = error.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendResetLink(String identifier) async {
    _authError = null;
    notifyListeners();
    try {
      await authService.sendResetLink(identifier);
      return true;
    } on AuthFailure catch (error) {
      _authError = error.message;
      notifyListeners();
      return false;
    }
  }

  void signOut() {
    try {
      authService.api.clearToken();
    } catch (_) {
      // Clearing a token never fails the sign-out.
    }
    // Best-effort; writes are serialised so this can't overtake a later save.
    SessionStore.instance.clear();
    _status = AuthStatus.unauthenticated;
    _data = const AppData();
    _authError = null;
    notifyListeners();
  }

  /// Rehydrates a persisted customer session after a cold start.
  ///
  /// Returns false when there is nothing to restore or the server rejected
  /// the stored token (expired / revoked) — the caller should fall through
  /// to the welcome screen. Network failures keep the session and let
  /// [loadAll] surface its own retry state.
  Future<bool> restoreSession() async {
    final stored = await SessionStore.instance.restore();
    if (stored == null || stored.isStaff) return false;
    authService.api.setToken(stored.token);
    authService.api.setRefreshToken(stored.refreshToken);
    repository.useApiClient(authService.api);
    try {
      final raw = await authService.api.get('/auth/me');
      final user = extractUserMap(raw);
      if (user != null) {
        _data = _data.copyWith(customer: Customer.fromJson(user));
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        signOut();
        return false;
      }
      // Offline or server hiccup — keep the session and load what we can.
    }
    _status = AuthStatus.authenticated;
    notifyListeners();
    await loadAll();
    return true;
  }

  Future<void> loadAll() async {
    _data = _data.copyWith(isLoadingData: true, clearError: true);
    notifyListeners();
    // Load each slice independently: a missing endpoint (reports/checkups/
    // addresses don't exist on the server) must not fail the whole screen.
    // Each fetch already returns safe fallbacks on error.
    Customer? customer = _data.customer;
    List<WaterService> services = _data.services;
    List<Booking> bookings = _data.bookings;
    List<AppNotification> notifications = _data.notifications;
    List<WaterReport> reports = _data.reports;
    List<CheckupAppointment> checkups = _data.checkups;
    List<ServiceAddress> addresses = _data.addresses;
    String? dataError;
    // Guests browse without a bearer token: the profile endpoints require
    // auth, so skip the fetch instead of surfacing an error on every guest
    // screen (home, services, history).
    if (repository.api.hasToken) {
      try {
        customer = await repository.fetchCustomer();
      } catch (error) {
        customer = null;
        dataError = error is DataFailure
            ? error.message
            : 'We could not load your profile. Please try again.';
      }
    } else {
      customer = null;
    }
    try {
      services = await repository.fetchServices();
    } catch (error) {
      dataError ??= error is DataFailure
          ? error.message
          : 'We could not load services. Please try again.';
    }
    try {
      bookings = await repository.fetchBookings();
    } catch (_) {}
    try {
      notifications = await repository.fetchNotifications();
    } catch (_) {}
    try {
      reports = await repository.fetchReports();
    } catch (_) {}
    try {
      checkups = await repository.fetchCheckups();
    } catch (_) {}
    try {
      addresses = await repository.fetchAddresses();
    } catch (_) {}
    _data = _data.copyWith(
      customer: customer,
      clearCustomer: customer == null,
      services: services,
      bookings: bookings,
      notifications: notifications,
      reports: reports,
      checkups: checkups,
      addresses: addresses,
      isLoadingData: false,
      dataError: dataError,
      clearError: dataError == null,
    );
    notifyListeners();
  }

  Future<void> reload() => loadAll();

  /// Cancels a booking. Returns false when the repository call fails.
  Future<bool> cancelBooking(String bookingId) async {
    try {
      await repository.cancelBooking(bookingId);
      await loadAll();
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> saveServiceLocation({
    String? id,
    required String label,
    required String address,
    String? city,
    String? state,
    String? pincode,
  }) async {
    await repository.saveAddress(
      id: id,
      label: label,
      address: address,
      city: city,
      state: state,
      pincode: pincode,
    );
    _data = _data.copyWith(addresses: await repository.fetchAddresses());
    notifyListeners();
  }

  Future<void> setDefaultServiceLocation(String id) async {
    await repository.setDefaultAddress(id);
    _data = _data.copyWith(addresses: await repository.fetchAddresses());
    notifyListeners();
  }

  Future<void> deleteServiceLocation(String id) async {
    await repository.deleteAddress(id);
    _data = _data.copyWith(addresses: await repository.fetchAddresses());
    notifyListeners();
  }

  /// Marks every notification as read and refreshes the snapshot.
  Future<void> markAllNotificationsRead() async {
    repository.markAllNotificationsRead();
    _data = _data.copyWith(
      notifications: _data.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
    );
    notifyListeners();
  }

  /// Marks a single notification as read and refreshes the snapshot.
  Future<void> markNotificationRead(String id) async {
    repository.markNotificationRead(id);
    _data = _data.copyWith(
      notifications: _data.notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList(),
    );
    notifyListeners();
  }
}

/// Provides [AppController] to descendants and rebuilds them on change.
class CustomerScope extends InheritedNotifier<AppController> {
  const CustomerScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CustomerScope>();
    assert(
      scope?.notifier != null,
      'CustomerScope.of() called outside of CustomerScope',
    );
    return scope!.notifier!;
  }
}
