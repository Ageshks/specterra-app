import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specterra_staff/core/network/api_client.dart';
import 'package:specterra_staff/customer_app/data/specterra_repository.dart';
import 'package:specterra_staff/customer_app/data/models/customer.dart';
import 'package:specterra_staff/customer_app/data/models/product.dart';
import 'package:specterra_staff/customer_app/data/models/water_service.dart';
import 'package:specterra_staff/customer_app/state/app_state.dart';

const _serviceJson = <String, dynamic>{
  'id': 'svc-1',
  'name': 'RO Service',
  'description': 'desc',
  'basePrice': '2600',
  'estimatedDuration': 120,
  'isActive': true,
  'category': {'name': 'RO Service'},
};

void main() {
  group('product models', () {
    test('parses product details and available photos', () {
      final product = Product.fromJson({
        'id': 'prod-1',
        'name': 'Replacement filter',
        'description': 'Annual replacement',
        'price': '1250.50',
        'photos': [
          'https://example.com/filter.jpg',
          {'imageUrl': 'https://example.com/filter-side.jpg'},
        ],
      });

      expect(product.id, 'prod-1');
      expect(product.name, 'Replacement filter');
      expect(product.price, 1251);
      expect(product.photos, [
        'https://example.com/filter.jpg',
        'https://example.com/filter-side.jpg',
      ]);
    });

    test('serializes only product id and selected quantity', () {
      expect(
        const ProductSelection(productId: 'prod-1', quantity: 3).toJson(),
        {'productId': 'prod-1', 'quantity': 3},
      );
    });

    test('reads company slug from customer profile shapes', () {
      expect(
        Customer.fromJson({
          'firstName': 'Sam',
          'company': {'slug': 'north-company'},
        }).companySlug,
        'north-company',
      );
      expect(
        Customer.fromJson({
          'name': 'Sam',
          'company_slug': 'south-company',
        }).companySlug,
        'south-company',
      );
      expect(
        Customer.fromJson({
          'name': 'Sam',
          'customer': {
            'company': {'slug': 'nested-company'},
          },
        }).companySlug,
        'nested-company',
      );
    });
  });

  group('SpecterraRepository.fetchProducts', () {
    test(
      'uses the profile company slug and unwraps paginated products',
      () async {
        final client = ApiClient(
          baseUrl: 'http://example.com/api/v1',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/api/v1/products');
            expect(request.url.queryParameters, {
              'companySlug': 'north-company',
            });
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'items': [
                    {
                      'id': 'prod-1',
                      'name': 'Replacement filter',
                      'price': 900,
                      'photos': ['https://example.com/filter.jpg'],
                    },
                  ],
                  'page': 1,
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        )..setToken('token');

        final products = await SpecterraRepository(
          api: client,
        ).fetchProducts('north-company');
        expect(products, hasLength(1));
        expect(products.first.id, 'prod-1');
        expect(products.first.photos, ['https://example.com/filter.jpg']);
      },
    );

    test('surfaces product API validation and connection errors', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Company catalogue is unavailable'}),
            422,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      await expectLater(
        SpecterraRepository(api: client).fetchProducts('north-company'),
        throwsA(
          isA<DataFailure>().having(
            (failure) => failure.message,
            'message',
            'Company catalogue is unavailable',
          ),
        ),
      );
    });
  });

  group('SpecterraRepository.confirmBooking product handling', () {
    final service = WaterService(
      id: 'svc-1',
      name: 'RO Service',
      description: '',
      icon: Icons.water_drop_outlined,
      price: 2600,
      durationMinutes: 60,
      category: ServiceCategory.roService,
    );

    test(
      'posts selected quantities and uses authoritative booking totals',
      () async {
        final client = ApiClient(
          baseUrl: 'http://example.com/api/v1',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/bookings');
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            expect(body['products'], [
              {'productId': 'prod-1', 'quantity': 2},
            ]);
            expect(body.containsKey('totalAmount'), isFalse);
            expect(body.containsKey('unitPrice'), isFalse);
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'booking-1',
                  'totalAmount': 5800,
                  'service': {'name': 'RO Service'},
                  'bookingProducts': [
                    {
                      'productName': 'Replacement filter',
                      'quantity': 2,
                      'unitPrice': 1600,
                      'lineTotal': 3200,
                    },
                  ],
                },
              }),
              201,
              headers: {'content-type': 'application/json'},
            );
          }),
        )..setToken('token');

        final booking = await SpecterraRepository(api: client).confirmBooking(
          service: service,
          scheduledAt: DateTime(2026, 12, 1, 10),
          address: 'Home',
          customerName: 'Sam',
          products: const [ProductSelection(productId: 'prod-1', quantity: 2)],
        );

        expect(booking.amount, 5800);
        expect(booking.bookingProducts, hasLength(1));
        expect(booking.bookingProducts.single.name, 'Replacement filter');
        expect(booking.bookingProducts.single.lineTotal, 3200);
      },
    );

    test('omits products when no optional products are selected', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body.containsKey('products'), isFalse);
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'booking-2',
                'totalAmount': 2600,
                'service': {'name': 'RO Service'},
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..setToken('token');

      final booking = await SpecterraRepository(api: client).confirmBooking(
        service: service,
        scheduledAt: DateTime(2026, 12, 1, 10),
        address: 'Home',
        customerName: 'Sam',
      );
      expect(booking.amount, 2600);
    });

    test('surfaces booking validation errors', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Product quantity is invalid'}),
            422,
            headers: {'content-type': 'application/json'},
          ),
        ),
      )..setToken('token');

      await expectLater(
        SpecterraRepository(api: client).confirmBooking(
          service: service,
          scheduledAt: DateTime(2026, 12, 1, 10),
          address: 'Home',
          customerName: 'Sam',
          products: const [ProductSelection(productId: 'prod-1', quantity: 1)],
        ),
        throwsA(
          isA<DataFailure>().having(
            (failure) => failure.message,
            'message',
            'Product quantity is invalid',
          ),
        ),
      );
    });
  });

  group('SpecterraRepository.fetchServices', () {
    test('unwraps { success, data } envelope', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'data': [_serviceJson],
            }),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SpecterraRepository(api: client);
      final services = await repo.fetchServices();
      expect(services, hasLength(1));
      expect(services.first.id, 'svc-1');
      expect(services.first.price, 2600);
    });

    test('returns [] for empty data', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'success': true, 'data': <dynamic>[]}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SpecterraRepository(api: client);
      expect(await repo.fetchServices(), isEmpty);
    });

    test('returns [] for null data', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'success': true, 'data': null}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SpecterraRepository(api: client);
      expect(await repo.fetchServices(), isEmpty);
    });

    test('unwraps bare list', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode([_serviceJson]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SpecterraRepository(api: client);
      final services = await repo.fetchServices();
      expect(services, hasLength(1));
    });
  });

  group('SpecterraRepository.fetchService', () {
    test('unwraps { success, data } envelope', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/services/svc-1')) {
            return http.Response(
              jsonEncode({'success': true, 'data': _serviceJson}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final repo = SpecterraRepository(api: client);
      final service = await repo.fetchService('svc-1');
      expect(service, isNotNull);
      expect(service!.id, 'svc-1');
    });

    test('falls back to list on 404', () async {
      final client = ApiClient(
        baseUrl: 'http://example.com/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/services/svc-1')) {
            return http.Response(
              jsonEncode({'message': 'Not found'}),
              404,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [_serviceJson],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final repo = SpecterraRepository(api: client);
      final service = await repo.fetchService('svc-1');
      expect(service, isNotNull);
      expect(service!.id, 'svc-1');
    });
  });
}
