import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specterra_staff/core/network/api_client.dart';
import 'package:specterra_staff/data/staff_repository.dart';

void main() {
  test(
    'registers and removes FCM device tokens through the staff API',
    () async {
      final requests = <http.Request>[];
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final repository = StaffRepository(
          api: ApiClient(
            httpClient: MockClient((request) async {
              requests.add(request);
              return http.Response(
                jsonEncode({'success': true, 'data': {}}),
                200,
              );
            }),
            baseUrl: 'https://example.test/api/v1',
          ),
        );

        await repository.registerDeviceToken('fcm:android-token');
        await repository.removeDeviceToken('fcm:android-token');

        expect(requests[0].method, 'PATCH');
        expect(requests[0].url.path, '/api/v1/notifications/devices');
        expect(jsonDecode(requests[0].body), {
          'token': 'fcm:android-token',
          'platform': 'ANDROID',
          'deviceName': 'android',
        });
        expect(requests[1].method, 'DELETE');
        expect(
          requests[1].url.path,
          '/api/v1/notifications/devices/fcm%3Aandroid-token',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'overtime request lets backend calculate duration before auto-checkout',
    () async {
      http.Request? overtimeRequest;
      final repository = StaffRepository(
        api: ApiClient(
          httpClient: MockClient((request) async {
            overtimeRequest = request;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'overtime-1',
                  'date': '2026-11-16',
                  'status': 'PENDING',
                },
              }),
              201,
            );
          }),
          baseUrl: 'https://example.test/api/v1',
        ),
      );

      final result = await repository.requestOvertime(
        date: DateTime(2026, 11, 16),
        reason: 'Finish assigned service',
        breakMinutes: 30,
      );

      expect(result.isSuccess, isTrue);
      final body = jsonDecode(overtimeRequest!.body) as Map<String, dynamic>;
      expect(body['date'], '2026-11-16');
      expect(body['reason'], 'Finish assigned service');
      expect(body['breakMinutes'], 30);
      expect(body.containsKey('requestedMinutes'), isFalse);
    },
  );

  test(
    'loads transfer recipients from the employee-accessible endpoint',
    () async {
      final requests = <http.Request>[];
      final repository = StaffRepository(
        api: ApiClient(
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'tech-1',
                    'name': 'Asha Rao',
                    'designation': 'Field Technician',
                    'availability': 'AVAILABLE',
                  },
                  {
                    'id': 'manager-1',
                    'name': 'Ravi Kumar',
                    'designation': 'Manager',
                    'availability': 'AVAILABLE',
                  },
                ],
              }),
              200,
            );
          }),
          baseUrl: 'https://example.test/api/v1',
        ),
      );

      final recipients = await repository.fetchStaff();

      expect(requests.single.url.path, '/api/v1/employees/transfer-targets');
      expect(recipients.map((staff) => staff.id), ['tech-1']);
    },
  );

  test('transfer request sends backend work order and employee IDs', () async {
    http.Request? transferRequest;
    final repository = StaffRepository(
      api: ApiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/work-assignments')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'assignment-1',
                    'status': 'ASSIGNED',
                    'workOrder': {
                      'id': 'order-1',
                      'customer': {'name': 'Customer One'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/work-transfers')) {
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({'success': true, 'data': []}),
                200,
              );
            }
            transferRequest = request;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 'transfer-1',
                  'workOrderId': 'order-1',
                  'requestedEmployeeId': 'technician-2',
                  'reason': 'Emergency',
                },
              }),
              201,
            );
          }
          return http.Response('{}', 404);
        }),
        baseUrl: 'https://example.test/api/v1',
      ),
    );

    await repository.fetchJobs();
    await repository.fetchTransfers();
    final result = await repository.requestTransfer(
      workId: 'assignment-1',
      requestedStaffId: 'technician-2',
      reason: 'Emergency',
    );

    expect(result.isSuccess, isTrue);
    final body = jsonDecode(transferRequest!.body) as Map<String, dynamic>;
    expect(body['workOrderId'], 'order-1');
    expect(body['workOrderId'], isNot('assignment-1'));
    expect(body['requestedEmployeeId'], 'technician-2');
    expect(body.containsKey('requestedAt'), isFalse);
  });

  test(
    'billing approval visibility follows the signed-in supervisor designation',
    () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/employees/me')) {
          return http.Response(jsonEncode({'message': 'Not available'}), 403);
        }
        if (request.url.path.endsWith('/auth/me')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'user': {
                  'id': 'user-1',
                  'role': 'EMPLOYEE',
                  'employee': {'id': 'employee-1', 'designation': 'Supervisor'},
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      final repository = StaffRepository(
        api: ApiClient(
          httpClient: client,
          baseUrl: 'https://example.test/api/v1',
        ),
      );

      await repository.fetchEmployee();

      expect(repository.role, 'EMPLOYEE');
      expect(repository.isSupervisor, isTrue);
    },
  );

  test(
    'billing repository sends draft, upload, approval and history requests',
    () async {
      final requests = <http.Request>[];
      var status = 'DRAFT';
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/billing/pending-approvals')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [_invoice(status: 'PENDING_APPROVAL')],
            }),
            200,
          );
        }
        if (path.endsWith('/history')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {'action': 'SUBMITTED', 'remarks': null},
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/attachments')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'receipt-1'},
            }),
            201,
          );
        }
        if (path.endsWith('/submit')) {
          status = 'PENDING_APPROVAL';
          return http.Response(
            jsonEncode({'success': true, 'data': _invoice(status: status)}),
            200,
          );
        }
        if (path.endsWith('/approve')) {
          status = 'APPROVED';
          return http.Response(
            jsonEncode({'success': true, 'data': _invoice(status: status)}),
            200,
          );
        }
        if (path.endsWith('/reject')) {
          status = 'REJECTED';
          return http.Response(
            jsonEncode({
              'success': true,
              'data': _invoice(
                status: status,
                rejectionReason: 'Attach the receipt',
              ),
            }),
            200,
          );
        }
        if (request.method == 'GET' && path.endsWith('/billing')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [_invoice(status: status)],
            }),
            200,
          );
        }
        if (request.method == 'POST' && path.endsWith('/billing')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['workOrderId'], 'work-order-1');
          expect((body['items'] as List), hasLength(2));
          return http.Response(
            jsonEncode({'success': true, 'data': _invoice(status: 'DRAFT')}),
            201,
          );
        }
        if (request.method == 'PUT' && path.endsWith('/invoice-1')) {
          expect(request.headers['authorization'], 'Bearer test-token');
          status = 'DRAFT';
          return http.Response(
            jsonEncode({'success': true, 'data': _invoice(status: status)}),
            200,
          );
        }
        return http.Response(
          jsonEncode({'success': true, 'data': _invoice(status: status)}),
          200,
        );
      });
      final api = ApiClient(
        httpClient: client,
        baseUrl: 'https://example.test/api/v1',
      )..setToken('test-token');
      final repository = StaffRepository(api: api);
      final items = [
        {
          'category': 'DELIVERY',
          'description': 'Courier',
          'quantity': 1,
          'unitPrice': 80,
        },
        {
          'category': 'MATERIAL',
          'description': 'Filter',
          'quantity': 2,
          'unitPrice': 125.5,
        },
      ];

      final draft = await repository.createBilling(
        workOrderId: 'work-order-1',
        items: items,
      );
      expect(draft.status, 'DRAFT');
      expect(draft.gstRate, 18);
      expect(draft.cgstAmount, 119.79);
      expect(draft.sgstAmount, 119.79);
      expect(draft.finalAmount, 1570.58);
      expect(draft.items.map((item) => item.description), [
        'Courier',
        'Filter',
      ]);
      final saved = await repository.updateBilling(id: draft.id, items: items);
      expect(saved.items, hasLength(2));
      await repository.uploadBillingReceipt(
        invoiceId: draft.id,
        invoiceItemId: 'item-1',
        bytes: [1, 2, 3],
        fileName: 'receipt.jpg',
      );
      expect(
        (await repository.submitBilling(draft.id)).status,
        'PENDING_APPROVAL',
      );
      expect(
        (await repository.fetchPendingBillings()).single.status,
        'PENDING_APPROVAL',
      );
      expect(
        (await repository.decideBilling(
          id: draft.id,
          approve: false,
          remarks: 'Attach the receipt',
        )).status,
        'REJECTED',
      );
      expect(
        (await repository.updateBilling(id: draft.id, items: items)).status,
        'DRAFT',
      );
      expect(
        (await repository.submitBilling(draft.id)).status,
        'PENDING_APPROVAL',
      );
      expect(
        (await repository.decideBilling(
          id: draft.id,
          approve: true,
          remarks: 'Looks good',
        )).status,
        'APPROVED',
      );
      expect(
        (await repository.fetchBillingHistory(draft.id)).single['action'],
        'SUBMITTED',
      );
      expect(
        (await repository.fetchBillings(workOrderId: 'work-order-1')).single.id,
        'invoice-1',
      );

      expect(
        requests.map((request) => request.url.path),
        containsAll([
          '/api/v1/billing',
          '/api/v1/billing/invoice-1/attachments',
          '/api/v1/billing/invoice-1/submit',
          '/api/v1/billing/pending-approvals',
          '/api/v1/billing/invoice-1/reject',
          '/api/v1/billing/invoice-1/approve',
          '/api/v1/billing/invoice-1/history',
        ]),
      );
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer test-token',
        ),
        isTrue,
      );
    },
  );
}

Map<String, dynamic> _invoice({
  required String status,
  String? rejectionReason,
}) => {
  'id': 'invoice-1',
  'workOrderId': 'work-order-1',
  'workOrder': {'id': 'work-order-1', 'workOrderNumber': 'WO-101'},
  'customer': {
    'user': {'firstName': 'Mira', 'lastName': 'Shah'},
  },
  'service': {'name': 'Filter service', 'gstRate': 18},
  'baseServicePrice': 1000,
  'taxableAmount': 1331,
  'gstRate': 18,
  'gstAmount': 239.58,
  'cgstAmount': 119.79,
  'sgstAmount': 119.79,
  'igstAmount': 0,
  'finalAmount': 1570.58,
  'status': status,
  'rejectionReason': rejectionReason,
  'items': [
    {
      'id': 'item-1',
      'category': 'DELIVERY',
      'description': 'Courier',
      'quantity': 1,
      'unitPrice': 80,
      'amount': 80,
      'attachments': [],
    },
    {
      'id': 'item-2',
      'category': 'MATERIAL',
      'description': 'Filter',
      'quantity': 2,
      'unitPrice': 125.5,
      'amount': 251,
      'attachments': [],
    },
  ],
  'attachments': [],
};
