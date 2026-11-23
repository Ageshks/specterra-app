import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:specterra_staff/core/network/api_client.dart';
import 'package:specterra_staff/core/session_store.dart';
import 'package:specterra_staff/customer_app/data/auth_service.dart';
import 'package:specterra_staff/customer_app/data/specterra_repository.dart';
import 'package:specterra_staff/customer_app/state/app_state.dart'
    as customer_state;
import 'package:specterra_staff/data/staff_repository.dart';
import 'package:specterra_staff/features/shell/app_shell.dart';
import 'package:specterra_staff/features/splash/splash_screen.dart';
import 'package:specterra_staff/features/auth/unified_login_screen.dart';
import 'package:specterra_staff/features/unified_home_screen.dart';
import 'package:specterra_staff/state/app_controller.dart';

/// Login sessions must survive an app restart: a successful login persists
/// the bearer token + role, the splash restores it on the next launch, and
/// sign-out (or an expired token) wipes it again.
///
/// All HTTP is faked via a scripted [http.Client] so no test touches the
/// network. Unimplemented verbs throw via [Fake].
class _FakeHttp extends Fake implements http.Client {
  _FakeHttp(this._handler);

  final Future<http.Response> Function(Uri url) _handler;

  @override
  Future<http.Response> get(Uri url, {Map<String, String>? headers}) =>
      _handler(url);

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
  }) => _handler(url);
}

const String _token = 'persisted-token';

/// Prefs seeded as if a previous run had signed in.
Map<String, Object> _prefs({required bool isStaff}) => <String, Object>{
  'specterra.session.token': _token,
  'specterra.session.role': isStaff ? 'EMPLOYEE' : 'CUSTOMER',
  'specterra.session.isStaff': isStaff,
};

Map<String, dynamic> _user({required String role}) => <String, dynamic>{
  'id': 'u-1',
  'firstName': 'Ana',
  'lastName': 'Reyes',
  'email': 'ana@specterra.test',
  'role': role,
  if (role != 'CUSTOMER')
    'employee': <String, dynamic>{'employeeId': 'SPT-1042'},
};

String _envelope(Object? data) =>
    jsonEncode(<String, Object?>{'success': true, 'data': data});

/// GET responses: profile endpoints return the staff user, everything else
/// an empty list envelope.
Future<http.Response> _staffApi(Uri url) async {
  if (url.path.contains('/auth/me') || url.path.contains('/employees/me')) {
    return http.Response(_envelope({'user': _user(role: 'EMPLOYEE')}), 200);
  }
  return http.Response(_envelope(<dynamic>[]), 200);
}

/// `POST /auth/login` returns the live VPS envelope with nested tokens.
Future<http.Response> _staffLoginApi(Uri url) async {
  if (url.path.endsWith('/auth/login')) {
    return http.Response(
      _envelope({
        'user': _user(role: 'EMPLOYEE'),
        'tokens': <String, String>{
          'accessToken': _token,
          'refreshToken': 'refresh-token',
        },
      }),
      200,
    );
  }
  return _staffApi(url);
}

/// Customer API: profile for `/auth/me`, empty lists everywhere else.
Future<http.Response> _customerApi(Uri url) async {
  if (url.path.contains('/auth/me')) {
    return http.Response(_envelope({'user': _user(role: 'CUSTOMER')}), 200);
  }
  return http.Response(_envelope(<dynamic>[]), 200);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SessionStore', () {
    test('save → restore → clear round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = SessionStore.instance;

      await store.save(token: _token, role: 'EMPLOYEE', isStaff: true);
      final restored = await store.restore();
      expect(restored, isNotNull);
      expect(restored!.token, _token);
      expect(restored.role, 'EMPLOYEE');
      expect(restored.isStaff, isTrue);

      await store.clear();
      expect(await store.restore(), isNull);
    });

    test('restore returns null when nothing was persisted', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await SessionStore.instance.restore(), isNull);
    });
  });

  group('staff session', () {
    test('repositoryLogin persists token, role and scope', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AppController(
        repository: StaffRepository(
          api: ApiClient(httpClient: _FakeHttp(_staffLoginApi)),
        ),
      );
      addTearDown(controller.dispose);

      await controller.repositoryLogin(
        employeeId: 'ana@specterra.test',
        password: 'secret123',
      );

      final stored = await SessionStore.instance.restore();
      expect(stored, isNotNull);
      expect(stored!.token, _token);
      expect(stored.role, 'EMPLOYEE');
      expect(stored.isStaff, isTrue);
    });

    test('restoreSession rehydrates the employee after a restart', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: true));
      final controller = AppController(
        repository: StaffRepository(
          api: ApiClient(httpClient: _FakeHttp(_staffApi)),
        ),
      );
      addTearDown(controller.dispose);

      final restored = await controller.restoreSession();

      expect(restored, isTrue);
      expect(controller.data.isSignedIn, isTrue);
      expect(controller.data.employee?.role, 'EMPLOYEE');
      expect(controller.data.employee?.employeeId, 'SPT-1042');
    });

    test('expired staff token is dropped, not restored', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: true));
      final api = ApiClient(
        httpClient: _FakeHttp((_) async => http.Response('{}', 401)),
      );
      final controller = AppController(repository: StaffRepository(api: api));
      addTearDown(controller.dispose);

      final restored = await controller.restoreSession();

      expect(restored, isFalse);
      expect(controller.data.isSignedIn, isFalse);
      expect(api.hasToken, isFalse);
      expect(await SessionStore.instance.restore(), isNull);
    });

    test('signOut clears the persisted session', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: true));
      final controller = AppController(
        repository: StaffRepository(
          api: ApiClient(httpClient: _FakeHttp(_staffApi)),
        ),
      );
      addTearDown(controller.dispose);
      expect(await controller.restoreSession(), isTrue);

      await controller.signOut();

      expect(controller.data.isSignedIn, isFalse);
      // Writes are serialised, so the next read observes the clear.
      expect(await SessionStore.instance.restore(), isNull);
    });

    testWidgets('cold start restores straight into the staff shell', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: true));
      final controller = AppController(
        repository: StaffRepository(
          api: ApiClient(httpClient: _FakeHttp(_staffApi)),
        ),
      );
      addTearDown(controller.dispose);

      // Fresh widget tree, exactly like a relaunched app. AppScope sits
      // above MaterialApp (as in StaffApp) so pushed routes can read it.
      await tester.pumpWidget(
        AppScope(
          controller: controller,
          child: MaterialApp(home: const SplashScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });

  group('customer session', () {
    test('restoreSession rehydrates the profile after a restart', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: false));
      final api = ApiClient(httpClient: _FakeHttp(_customerApi));
      final controller = customer_state.AppController(
        repository: SpecterraRepository(api: api, latency: Duration.zero),
        authService: AuthService(api: api, latency: Duration.zero),
      );
      addTearDown(controller.dispose);

      final restored = await controller.restoreSession();

      expect(restored, isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.customer?.name, 'Ana Reyes');
      expect(controller.customer?.email, 'ana@specterra.test');
      expect(api.token, _token);
    });

    test('expired customer token is dropped, not restored', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: false));
      final api = ApiClient(
        httpClient: _FakeHttp((_) async => http.Response('{}', 401)),
      );
      final controller = customer_state.AppController(
        repository: SpecterraRepository(api: api, latency: Duration.zero),
        authService: AuthService(api: api, latency: Duration.zero),
      );
      addTearDown(controller.dispose);

      final restored = await controller.restoreSession();

      expect(restored, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(await SessionStore.instance.restore(), isNull);
    });

    test('signOut clears the persisted session', () async {
      SharedPreferences.setMockInitialValues(_prefs(isStaff: false));
      final api = ApiClient(httpClient: _FakeHttp(_customerApi));
      final controller = customer_state.AppController(
        repository: SpecterraRepository(api: api, latency: Duration.zero),
        authService: AuthService(api: api, latency: Duration.zero),
      );
      addTearDown(controller.dispose);
      expect(await controller.restoreSession(), isTrue);

      controller.signOut();

      expect(controller.isAuthenticated, isFalse);
      // Writes are serialised, so the next read observes the clear.
      expect(await SessionStore.instance.restore(), isNull);
    });
  });

  testWidgets('cold start without a session shows the login screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      repository: StaffRepository(
        api: ApiClient(httpClient: _FakeHttp(_staffApi)),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      AppScope(
        controller: controller,
        child: MaterialApp(home: const SplashScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(UnifiedLoginScreen), findsOneWidget);
    expect(find.byType(UnifiedHomeScreen), findsNothing);
    expect(find.byType(AppShell), findsNothing);
  });
}
