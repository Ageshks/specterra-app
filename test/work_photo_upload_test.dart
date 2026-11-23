import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specterra_staff/core/network/api_client.dart';
import 'package:specterra_staff/data/models/models.dart';
import 'package:specterra_staff/data/staff_repository.dart';

void main() {
  test(
    'uploads multiple report photos and preserves per-file failures',
    () async {
      http.Request? uploadRequest;
      final api = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/work-assignments')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'assignment-1',
                    'status': 'COMPLETED',
                    'workOrder': {
                      'id': 'order-1',
                      'serviceReport': {'id': 'report-1', 'status': 'DRAFT'},
                    },
                  },
                ],
              }),
              200,
            );
          }
          uploadRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'photos': [
                  {
                    'id': 'photo-1',
                    'imageUrl': '/uploads/work-photos/one.jpg',
                    'thumbnailUrl': '/uploads/work-photos/one-thumb.jpg',
                  },
                  {
                    'id': 'photo-2',
                    'imageUrl': 'https://res.cloudinary.com/demo/two.jpg',
                  },
                ],
                'failures': [
                  {'fileName': 'bad.webp', 'message': 'Unsupported image'},
                ],
              },
            }),
            200,
          );
        }),
      );
      api.setToken('staff-token');
      final repository = StaffRepository(api: api);
      await repository.fetchJobs();

      final result = await repository.uploadWorkReportPhotos(
        workOrderId: 'assignment-1',
        serviceReportId: 'report-1',
        caption: 'After repair',
        files: const [
          WorkPhotoUploadFile(
            fileName: 'one.jpg',
            bytes: [1, 2, 3],
            contentType: 'image/jpeg',
          ),
          WorkPhotoUploadFile(
            fileName: 'two.png',
            bytes: [4, 5, 6],
            contentType: 'image/png',
          ),
          WorkPhotoUploadFile(
            fileName: 'bad.webp',
            bytes: [7, 8, 9],
            contentType: 'image/webp',
          ),
        ],
      );

      expect(uploadRequest, isNotNull);
      expect(uploadRequest!.method, 'POST');
      expect(uploadRequest!.url.path, '/api/v1/work-photos/batch');
      expect(uploadRequest!.headers['authorization'], 'Bearer staff-token');
      expect(
        uploadRequest!.headers['content-type'],
        startsWith('multipart/form-data; boundary='),
      );
      final body = uploadRequest!.body;
      expect(
        RegExp(r'name="photos"; filename=').allMatches(body),
        hasLength(3),
      );
      expect(body, contains('name="workOrderId"'));
      expect(body, contains('order-1'));
      expect(body, contains('name="serviceReportId"'));
      expect(body, contains('report-1'));
      expect(body, contains('After repair'));

      expect(result, isA<Success<WorkPhotoUploadResult>>());
      final upload = (result as Success<WorkPhotoUploadResult>).value;
      expect(upload.photos, hasLength(2));
      expect(
        upload.photos.first.imageUrl,
        'https://example.test/uploads/work-photos/one.jpg',
      );
      expect(
        upload.photos.first.thumbnailUrl,
        'https://example.test/uploads/work-photos/one-thumb.jpg',
      );
      expect(
        upload.photos.last.imageUrl,
        'https://res.cloudinary.com/demo/two.jpg',
      );
      expect(upload.failures, hasLength(1));
      expect(upload.failures.single.fileName, 'bad.webp');
      expect(upload.failures.single.message, 'Unsupported image');
    },
  );

  test('single upload uses the single-photo endpoint and field name', () async {
    http.Request? uploadRequest;
    final repository = StaffRepository(
      api: ApiClient(
        baseUrl: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/work-assignments')) {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {
                    'id': 'order-2',
                    'status': 'COMPLETED',
                    'workOrderId': 'order-2',
                  },
                ],
              }),
              200,
            );
          }
          uploadRequest = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 'photo-3',
                'imageUrl': '/uploads/work-photos/single.webp',
              },
            }),
            201,
          );
        }),
      ),
    );
    await repository.fetchJobs();

    final result = await repository.uploadWorkReportPhotos(
      workOrderId: 'order-2',
      files: const [
        WorkPhotoUploadFile(
          fileName: 'single.webp',
          bytes: [1, 2, 3],
          contentType: 'image/webp',
        ),
      ],
    );

    expect(uploadRequest!.url.path, '/api/v1/work-photos');
    expect(
      uploadRequest!.body,
      contains('name="photo"; filename="single.webp"'),
    );
    expect(result, isA<Success<WorkPhotoUploadResult>>());
    expect(
      (result as Success<WorkPhotoUploadResult>).value.photos.single.imageUrl,
      'https://example.test/uploads/work-photos/single.webp',
    );
  });

  test(
    'rejects more than ten photos per batch before making a request',
    () async {
      var uploadRequests = 0;
      final repository = StaffRepository(
        api: ApiClient(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/work-assignments')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'order-3',
                      'status': 'COMPLETED',
                      'workOrderId': 'order-3',
                    },
                  ],
                }),
                200,
              );
            }
            uploadRequests++;
            return http.Response('{}', 200);
          }),
        ),
      );
      await repository.fetchJobs();

      final result = await repository.uploadWorkReportPhotos(
        workOrderId: 'order-3',
        files: List.generate(
          11,
          (index) => WorkPhotoUploadFile(
            fileName: 'photo-$index.jpg',
            bytes: const [1],
            contentType: 'image/jpeg',
          ),
        ),
      );

      expect(result, isA<Failure<WorkPhotoUploadResult>>());
      expect(uploadRequests, 0);
    },
  );

  test(
    'updates an existing service report with PATCH and resubmits by ID',
    () async {
      final requests = <http.Request>[];
      final repository = StaffRepository(
        api: ApiClient(
          baseUrl: 'https://example.test/api/v1',
          httpClient: MockClient((request) async {
            requests.add(request);
            if (request.url.path.endsWith('/work-assignments')) {
              return http.Response(
                jsonEncode({
                  'success': true,
                  'data': [
                    {
                      'id': 'assignment-4',
                      'status': 'COMPLETED',
                      'workOrder': {'id': 'order-4'},
                    },
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 'report-4'},
              }),
              200,
            );
          }),
        ),
      );
      await repository.fetchJobs();

      await repository.saveEmployeeServiceReport(
        workOrderId: 'assignment-4',
        reportId: 'report-4',
        workSummary: 'Repaired the pump',
        workPerformed: 'Replaced the worn seal and tested the unit.',
      );
      await repository.submitEmployeeServiceReport('report-4');

      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/api/v1/service-reports/report-4');
      expect(jsonDecode(requests[1].body), {
        'workOrderId': 'order-4',
        'workSummary': 'Repaired the pump',
        'workPerformed': 'Replaced the worn seal and tested the unit.',
      });
      expect(requests[2].method, 'POST');
      expect(requests[2].url.path, '/api/v1/service-reports/report-4/submit');
    },
  );

  test(
    'resolves report photo URLs from the API origin, preserving absolutes',
    () {
      final report = ServiceReport.fromJson({
        'id': 'report-42',
        'status': 'APPROVED',
        'reviewResult': 'Approved after review',
        'photos': [
          {
            'imageUrl': '/uploads/work-photos/site.jpg',
            'thumbnailUrl': '/uploads/work-photos/site-thumb.jpg',
          },
          {
            'imageUrl': 'https://res.cloudinary.com/demo/existing.jpg',
            'thumbnailUrl':
                'https://res.cloudinary.com/demo/existing-thumb.jpg',
          },
        ],
      }, resolveUrl: ApiConfig.resolveMediaUrl);

      expect(report.photos, hasLength(2));
      expect(
        report.photos.first.imageUrl,
        'https://crm.nextradev.com/uploads/work-photos/site.jpg',
      );
      expect(
        report.photos.first.previewUrl,
        'https://crm.nextradev.com/uploads/work-photos/site-thumb.jpg',
      );
      expect(
        report.photos.last.imageUrl,
        'https://res.cloudinary.com/demo/existing.jpg',
      );
      expect(
        ApiConfig.resolveMediaUrl(
          '/uploads/work-photos/site.jpg',
          apiBaseUrl: 'https://api.example.test/api/v1',
        ),
        'https://api.example.test/uploads/work-photos/site.jpg',
      );
    },
  );

  test('loads the report status and its existing photos from a work order', () {
    final job = WorkJob.fromJson({
      'id': 'assignment-5',
      'status': 'COMPLETED',
      'workOrder': {
        'id': 'order-5',
        'serviceReport': {
          'id': 'report-5',
          'status': 'APPROVED',
          'workSummary': 'Pump repair completed',
          'workPerformed': 'Replaced seal and tested flow',
          'reviewResult': 'Approved by supervisor',
          'photos': [
            {
              'imageUrl': '/uploads/work-photos/repair.jpg',
              'thumbnailUrl': '/uploads/work-photos/repair-thumb.jpg',
            },
            {
              'imageUrl': 'https://res.cloudinary.com/demo/older-photo.jpg',
            },
          ],
        },
      },
    });

    expect(job.reportReviewStatus.name, 'approved');
    expect(job.report?.id, 'report-5');
    expect(job.report?.workPerformed, 'Replaced seal and tested flow');
    expect(job.report?.reviewResult, 'Approved by supervisor');
    expect(job.report?.photos, hasLength(2));
    expect(
      job.report?.photos.first.imageUrl,
      'https://crm.nextradev.com/uploads/work-photos/repair.jpg',
    );
    expect(
      job.report?.photos.last.imageUrl,
      'https://res.cloudinary.com/demo/older-photo.jpg',
    );
  });

  test('parses editable and approved service report statuses', () {
    final draft = ServiceReport.fromJson({
      'id': 'draft-1',
      'status': 'DRAFT',
    }, resolveUrl: ApiConfig.resolveMediaUrl);
    final correction = ServiceReport.fromJson({
      'id': 'correction-1',
      'status': 'CORRECTION_REQUIRED',
    }, resolveUrl: ApiConfig.resolveMediaUrl);
    final approved = ServiceReport.fromJson({
      'id': 'approved-1',
      'status': 'APPROVED',
    }, resolveUrl: ApiConfig.resolveMediaUrl);

    expect(draft.canEdit, isTrue);
    expect(correction.canEdit, isTrue);
    expect(approved.canEdit, isFalse);
    expect(approved.reviewResult, isEmpty);
  });
}
