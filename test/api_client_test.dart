import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specterra_staff/core/network/api_client.dart';
import 'package:specterra_staff/customer_app/data/auth_service.dart';
import 'package:specterra_staff/customer_app/data/models/customer.dart';
import 'package:specterra_staff/data/models/models.dart';

void main() {
  group('ApiConfig', () {
    test('defaults to the live VPS api', () {
      expect(ApiConfig.baseUrl, 'https://crm.nextradev.com/api/v1');
    });
  });

  group('ApiClient', () {
    test('returns the live envelope untouched on success', () async {
      final client = ApiClient(
        baseUrl: 'http://187.127.176.132/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {'email': 'a@b.com'},
                'tokens': {'accessToken': 'abc'},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final decoded =
          await client.post('/auth/login', body: {}) as Map<String, dynamic>;
      expect(extractAuthToken(decoded), 'abc');
      expect(extractUserMap(decoded), {'email': 'a@b.com'});
    });

    test('throws user message from error payload', () async {
      final client = ApiClient(
        baseUrl: 'http://187.127.176.132/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Wrong password'}),
            401,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      try {
        await client.post('/auth/login', body: {});
        fail('expected ApiException');
      } on ApiException catch (error) {
        expect(error.message, 'Wrong password');
        expect(error.statusCode, 401);
      }
    });

    test(
      'includes validation field details in generic validation errors',
      () async {
        final client = ApiClient(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'message': 'Validation failed',
                'errors': {
                  'fields': ['requestedEmployeeId must be a UUID'],
                },
              }),
              400,
            ),
          ),
        );

        expect(
          () => client.post('/work-transfers', body: {}),
          throwsA(
            isA<ApiException>().having(
              (error) => error.message,
              'message',
              'Validation failed: fields: requestedEmployeeId must be a UUID',
            ),
          ),
        );
      },
    );
  });

  group('token + user extraction', () {
    test('finds tokens in the live envelope', () {
      expect(
        extractAuthToken({
          'data': {
            'tokens': {'accessToken': 't2'},
          },
        }),
        't2',
      );
      expect(extractAuthToken({'token': 't1'}), 't1');
      expect(
        extractAuthToken({
          'data': {
            'user': {'token': 't3'},
          },
        }),
        't3',
      );
      expect(
        extractRefreshToken({
          'data': {
            'tokens': {'refreshToken': 'r1'},
          },
        }),
        'r1',
      );
    });

    test('finds user in the live envelope', () {
      expect(
        extractUserMap({
          'data': {
            'user': {'name': 'A'},
          },
        }),
        {'name': 'A'},
      );
      expect(extractUserMap({'name': 'B'}), {'name': 'B'});
      // Register returns the user directly as data.
      expect(
        extractUserMap({
          'data': {'firstName': 'C', 'email': 'c@d.com'},
        }),
        {'firstName': 'C', 'email': 'c@d.com'},
      );
    });

    test('Customer.fromJson tolerates split names', () {
      final customer = Customer.fromJson({
        'firstName': 'Jane',
        'lastName': 'Doe',
        'email': 'jane@example.com',
      });
      expect(customer.name, 'Jane Doe');
      expect(customer.email, 'jane@example.com');
      expect(customer.initials, 'JD');
    });

    test('Employee.fromJson tolerates snake_case', () {
      final employee = Employee.fromJson({
        'employee_id': 'SPT-1042',
        'full_name': 'Arjun Menon',
      });
      expect(employee.employeeId, 'SPT-1042');
      expect(employee.initials, 'AM');
    });
  });

  group('auth services surface connection errors', () {
    test('customer signIn fails loudly without a server', () async {
      final service = AuthService(
        latency: Duration.zero,
        api: ApiClient(
          baseUrl: 'http://127.0.0.1:9/api/v1',
          httpClient: MockClient((_) async {
            throw http.ClientException('unreachable');
          }),
        ),
      );
      // The live app has no offline demo fallback: an unreachable server
      // must surface a clear connection error instead of a fake session.
      expect(
        () => service.signIn('user@example.com', 'password123'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            contains('Could not reach the server'),
          ),
        ),
      );
    });
  });
}
