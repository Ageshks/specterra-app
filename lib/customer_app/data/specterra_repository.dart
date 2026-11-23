import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../state/app_data.dart' show DataFailure;
import 'models/booking.dart';
import 'models/customer.dart';
import 'models/product.dart';
import 'models/supporting_models.dart';
import 'models/water_service.dart';

class ServiceReportPhoto {
  const ServiceReportPhoto({
    required this.imageUrl,
    this.thumbnailUrl,
    this.caption,
  });
  final String imageUrl;
  final String? thumbnailUrl;
  final String? caption;
}

class CustomerServiceReport {
  const CustomerServiceReport({
    required this.id,
    required this.reportNumber,
    required this.status,
    required this.serviceName,
    required this.bookingNumber,
    required this.workOrderNumber,
    this.workSummary,
    this.workPerformed,
    this.issuesFound,
    this.materialsUsed,
    this.recommendations,
    this.completionRemarks,
    this.technician,
    this.reviewer,
    this.submittedAt,
    this.photos = const [],
  });
  final String id,
      reportNumber,
      status,
      serviceName,
      bookingNumber,
      workOrderNumber;
  final String? workSummary,
      workPerformed,
      issuesFound,
      materialsUsed,
      recommendations,
      completionRemarks,
      technician,
      reviewer,
      submittedAt;
  final List<ServiceReportPhoto> photos;

  factory CustomerServiceReport.fromHistory(Map<String, dynamic> row) {
    final report = row['serviceReport'];
    if (report is! Map<String, dynamic> ||
        report['status']?.toString().toUpperCase() != 'APPROVED') {
      throw const FormatException('Report is not approved');
    }
    final booking = row['booking'] is Map<String, dynamic>
        ? row['booking'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final service = booking['service'] is Map<String, dynamic>
        ? booking['service'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final workOrder = row['workOrder'] is Map<String, dynamic>
        ? row['workOrder'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final employee = report['employee'] is Map<String, dynamic>
        ? report['employee'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final employeeUser = employee['user'] is Map<String, dynamic>
        ? employee['user'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final reviewer = report['reviewedBy'] is Map<String, dynamic>
        ? report['reviewedBy'] as Map<String, dynamic>
        : const <String, dynamic>{};
    String? name(Map<String, dynamic> user) {
      final value = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'
          .trim();
      return value.isEmpty ? null : value;
    }

    String? str(String key) => report[key]?.toString();
    final photos = report['photos'] is List
        ? (report['photos'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (p) => ServiceReportPhoto(
                  imageUrl: (p['imageUrl'] ?? '').toString(),
                  thumbnailUrl: p['thumbnailUrl']?.toString(),
                  caption: p['caption']?.toString(),
                ),
              )
              .where((p) => p.imageUrl.isNotEmpty)
              .toList()
        : const <ServiceReportPhoto>[];
    return CustomerServiceReport(
      id: (report['id'] ?? '').toString(),
      reportNumber: (report['reportNumber'] ?? 'Service report').toString(),
      status: 'APPROVED',
      serviceName: (service['name'] ?? 'Service visit').toString(),
      bookingNumber: (booking['bookingNumber'] ?? '').toString(),
      workOrderNumber: (workOrder['workOrderNumber'] ?? '').toString(),
      workSummary: str('workSummary'),
      workPerformed: str('workPerformed'),
      issuesFound: str('issuesFound'),
      materialsUsed: str('materialsUsed'),
      recommendations: str('recommendations'),
      completionRemarks: str('completionRemarks'),
      technician: name(employeeUser),
      reviewer: name(reviewer),
      submittedAt: str('submittedAt'),
      photos: photos,
    );
  }
}

class CustomerServiceReportPage {
  const CustomerServiceReportPage({
    required this.reports,
    required this.page,
    required this.totalPages,
  });
  final List<CustomerServiceReport> reports;
  final int page, totalPages;
}

/// Data source for the customer app, backed by the SPECTERRA backend at
/// [ApiConfig.baseUrl].
///
/// Live endpoints (verified Oct 2026):
/// * `GET /services` (public) — service catalog, envelope `data: []`
/// * `GET /products?companySlug=...` — active company product catalog
/// * `GET /bookings` (auth) — customer bookings, envelope `data: []`
/// * `POST /bookings` (auth) — `{ serviceId, serviceLocationId,
///   preferredDate (ISO), preferredTime (HH:mm), optional products:
///   `{ productId, quantity }[] }`; backend returns authoritative totals
/// * `GET /notifications` (auth) — envelope `data: []`
/// * `GET /auth/me`, `GET /users/me` (auth) — profile
///
/// Endpoints that do NOT exist on the server (reports / checkups) return
/// empty lists locally instead of fake seed data, so new accounts start clean
/// with honest empty states. Service locations are stored via
/// `/customers/me/addresses`.
class SpecterraRepository {
  SpecterraRepository({
    this.latency = const Duration(milliseconds: 650),
    ApiClient? api,
  }) : _api = api ?? ApiClient();

  final Duration latency;
  final ApiClient _api;

  ApiClient get api => _api;

  /// Lets the auth flow share one authenticated client with this repository.
  void useApiClient(ApiClient client) {
    // ApiClient holds the bearer token; repositories created before login
    // pick it up by copying the token over.
    if (client.token != null) _api.setToken(client.token);
  }

  /// Bookings created during this session, newest first (kept in memory so
  /// the UI reflects a just-placed booking even before a refetch).
  final List<Booking> _sessionBookings = <Booking>[];

  List<Booking> get sessionBookings =>
      List<Booking>.unmodifiable(_sessionBookings);

  /// Extracts the list payload from the live envelope
  /// (`{ data: [...] }`, `{ data: { items: [...] } }`, or a bare list).
  static List<Map<String, dynamic>> _asList(dynamic decoded) {
    dynamic data = decoded;
    // APIs commonly wrap pagination under data and then put the collection
    // under items/results, or return { data: { services/products: [...] } }.
    for (var depth = 0; depth < 4 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      dynamic next;
      for (final key in const [
        'data',
        'items',
        'results',
        'rows',
        'list',
        'services',
        'bookings',
        'products',
      ]) {
        if (map[key] != null) {
          next = map[key];
          break;
        }
      }
      if (next == null || identical(next, data)) break;
      data = next;
    }
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const <Map<String, dynamic>>[];
  }

  Future<List<Product>> fetchProducts(String companySlug) async {
    if (companySlug.trim().isEmpty) {
      throw const DataFailure(
        'Product catalogue is unavailable without a company profile.',
      );
    }
    try {
      final raw = await _api.get(
        '/products',
        query: {'companySlug': companySlug.trim()},
      );
      return _asList(raw)
          .where((json) => json['isActive'] != false && json['active'] != false)
          .map((json) {
            try {
              return Product.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<Product>()
          .where((product) => product.id.isNotEmpty)
          .toList();
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    } catch (_) {
      throw const DataFailure(
        'Could not load products. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------- services

  Future<List<WaterService>> fetchServices({
    int? page,
    int? limit,
    String? search,
    String? categoryId,
    bool? isActive,
    String? sortBy,
    String? sortOrder,
  }) async {
    final query = <String, String>{};
    if (page != null) query['page'] = page.toString();
    if (limit != null) query['limit'] = limit.toString();
    if (search != null && search.trim().isNotEmpty)
      query['search'] = search.trim();
    if (categoryId != null && categoryId.trim().isNotEmpty)
      query['categoryId'] = categoryId.trim();
    if (isActive != null) query['isActive'] = isActive.toString();
    if (sortBy != null && sortBy.trim().isNotEmpty)
      query['sortBy'] = sortBy.trim();
    if (sortOrder != null && sortOrder.trim().isNotEmpty)
      query['sortOrder'] = sortOrder.trim();
    try {
      final raw = await _api.get(
        '/services',
        query: query.isEmpty ? null : query,
      );
      final rows = _asList(raw);
      return rows
          .where((json) => json['isActive'] != false && json['active'] != false)
          .map((json) {
            try {
              return WaterService.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<WaterService>()
          .toList();
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    } catch (_) {
      throw const DataFailure(
        'Could not load services. Check your connection and try again.',
      );
    }
  }

  Future<WaterService?> fetchService(String id) async {
    // Prefer the dedicated endpoint; fall back to the cached list for guests
    // (GET /services/:id requires auth) or when the server is unreachable.
    try {
      final raw = await _api.get('/services/$id');
      dynamic data = raw;
      if (raw is Map<String, dynamic>) {
        data = raw['data'] ?? raw;
      }
      if (data is Map<String, dynamic>) {
        return WaterService.fromJson(data);
      }
    } on ApiException catch (error) {
      if (error.statusCode != 401 &&
          error.statusCode != 403 &&
          error.statusCode != 404) {
        // Fall through to list lookup.
      }
    } catch (_) {
      // Fall through to list lookup.
    }
    final services = await fetchServices();
    for (final service in services) {
      if (service.id == id) return service;
    }
    return null;
  }

  // ---------------------------------------------------------------- bookings

  Future<List<Booking>> fetchBookings() async {
    try {
      final raw = await _api.get('/bookings');
      final rows = _asList(raw);
      final remote = rows
          .map((json) {
            try {
              return Booking.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<Booking>()
          .toList();
      return <Booking>[..._sessionBookings, ...remote];
    } catch (_) {
      // Offline / unauthorized -> only session bookings, never fake history.
      return List<Booking>.unmodifiable(_sessionBookings);
    }
  }

  /// Creates a booking on the live backend and caches it for this session.
  ///
  /// Live contract: `POST /bookings` with `{ serviceId, serviceLocationId,
  /// preferredDate (ISO), preferredTime (HH:mm) }`. The app has no saved
  /// service locations on the server yet, so the typed address is sent as
  /// the location id text the server can store; name/phone/notes ride along
  /// when accepted.
  Future<Booking> confirmBooking({
    required WaterService service,
    required DateTime scheduledAt,
    required String address,
    required String customerName,
    String contactNumber = '',
    String notes = '',
    String? serviceLocationId,
    List<ProductSelection> products = const <ProductSelection>[],
  }) async {
    final locationId =
        (serviceLocationId != null && serviceLocationId.trim().isNotEmpty)
        ? serviceLocationId.trim()
        : address.trim();

    Booking fallback() {
      final now = DateTime.now();
      return Booking(
        id: 'SPT${now.millisecondsSinceEpoch.toString().substring(7)}',
        serviceId: service.id,
        serviceName: service.name,
        serviceIcon: service.icon,
        scheduledAt: scheduledAt,
        address: address,
        status: BookingStatus.upcoming,
        amount: service.price,
        customerName: customerName,
        contactNumber: contactNumber,
        notes: notes,
        trackingSteps: const <TrackingStep>[
          TrackingStep(
            title: 'Request submitted',
            timestamp: 'Just now',
            isCurrent: true,
          ),
          TrackingStep(title: 'Technician assigned', timestamp: 'Pending'),
          TrackingStep(title: 'On the way', timestamp: 'Pending'),
          TrackingStep(title: 'Service in progress', timestamp: 'Pending'),
          TrackingStep(title: 'Service completed', timestamp: 'Pending'),
        ],
      );
    }

    if (!_api.hasToken) {
      final booking = fallback();
      _sessionBookings.insert(0, booking);
      return booking;
    }

    try {
      final date =
          '${scheduledAt.year.toString().padLeft(4, '0')}-${scheduledAt.month.toString().padLeft(2, '0')}-${scheduledAt.day.toString().padLeft(2, '0')}';
      final time =
          '${scheduledAt.hour.toString().padLeft(2, '0')}:${scheduledAt.minute.toString().padLeft(2, '0')}';
      final remarksParts = <String>[];
      if (customerName.trim().isNotEmpty) {
        remarksParts.add('Name: ${customerName.trim()}');
      }
      if (contactNumber.trim().isNotEmpty) {
        remarksParts.add('Phone: ${contactNumber.trim()}');
      }
      if (notes.trim().isNotEmpty) {
        remarksParts.add(notes.trim());
      }

      final raw = await _api.post(
        '/bookings',
        body: {
          'serviceId': service.id,
          'serviceLocationId': locationId,
          'preferredDate': date,
          'preferredTime': time,
          if (remarksParts.isNotEmpty) 'remarks': remarksParts.join('\\n'),
          if (products.isNotEmpty)
            'products': products
                .map((selection) => selection.toJson())
                .toList(),
        },
      );
      final created = _bookingMap(raw);
      final booking = created == null ? fallback() : Booking.fromJson(created);
      _sessionBookings.insert(0, booking);
      return booking;
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    } catch (_) {
      throw const DataFailure(
        'Could not create booking. Check your connection and try again.',
      );
    }
  }

  static Map<String, dynamic>? _bookingMap(dynamic raw) {
    dynamic value = raw;
    for (var depth = 0; depth < 4 && value is Map; depth++) {
      final map = Map<String, dynamic>.from(value);
      dynamic next;
      for (final key in const ['booking', 'data', 'result']) {
        if (map[key] is Map) {
          next = map[key];
          break;
        }
      }
      if (next != null) {
        value = next;
        continue;
      }
      if (map.containsKey('id') ||
          map.containsKey('bookingId') ||
          map.containsKey('totalAmount') ||
          map.containsKey('bookingProducts')) {
        return map;
      }
      break;
    }
    return null;
  }

  Future<void> cancelBooking(String bookingId) async {
    // Cancel session bookings locally; try the server for remote ones but
    // never fail the UI when the endpoint is missing.
    final index = _sessionBookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      final existing = _sessionBookings[index];
      _sessionBookings[index] = Booking(
        id: existing.id,
        serviceId: existing.serviceId,
        serviceName: existing.serviceName,
        serviceIcon: existing.serviceIcon,
        scheduledAt: existing.scheduledAt,
        address: existing.address,
        status: BookingStatus.cancelled,
        amount: existing.amount,
        customerName: existing.customerName,
        contactNumber: existing.contactNumber,
        notes: 'Cancelled by customer.',
      );
      return;
    }
    for (final path in [
      '/bookings/$bookingId/cancel',
      '/bookings/$bookingId',
    ]) {
      try {
        if (path.endsWith('cancel')) {
          await _api.post(path);
        } else {
          await _api.delete(path);
        }
        return;
      } catch (_) {
        continue;
      }
    }
  }

  // ----------------------------------------------------------- notifications

  Future<List<AppNotification>> fetchNotifications() async {
    try {
      final raw = await _api.get('/notifications');
      return _asList(raw)
          .map((json) {
            try {
              return AppNotification.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<AppNotification>()
          .toList();
    } catch (_) {
      // No cached fakes — a new account genuinely has no notifications.
      return const <AppNotification>[];
    }
  }

  /// Marks every notification as read (server when available, else no-op).
  Future<void> markAllNotificationsRead() async {
    try {
      await _api.post('/notifications/read-all');
    } catch (_) {
      // Endpoint missing -> the in-memory snapshot in AppController already
      // flips to read, so nothing else is needed.
    }
  }

  /// Marks a single notification as read (server when available, else no-op).
  Future<void> markNotificationRead(String id) async {
    try {
      await _api.post('/notifications/$id/read');
    } catch (_) {
      // See above.
    }
  }

  // ----------------------------------------------------------------- reports

  /// No `GET /reports` on the server — new accounts have no reports.
  Future<List<WaterReport>> fetchReports() async => const <WaterReport>[];

  Future<CustomerServiceReportPage> fetchCustomerServiceReports({
    int page = 1,
    int limit = 20,
  }) async {
    if (!_api.hasToken)
      throw const DataFailure(
        'Sign in with your customer account to view service reports.',
      );
    try {
      final raw = await _api.get(
        '/customers/me/service-history',
        query: {'page': '$page', 'limit': '$limit'},
      );
      final rows = _asList(raw);
      final reports = <CustomerServiceReport>[];
      for (final row in rows) {
        try {
          reports.add(CustomerServiceReport.fromHistory(row));
        } on FormatException {
          /* Pending and non-approved reports stay private. */
        }
      }
      dynamic root = raw;
      if (root is Map && root['data'] is Map) root = root['data'];
      final pagination = raw is Map && raw['pagination'] is Map
          ? raw['pagination'] as Map
          : (root is Map && root['pagination'] is Map
                ? root['pagination'] as Map
                : const {});
      return CustomerServiceReportPage(
        reports: reports,
        page: page,
        totalPages: int.tryParse('${pagination['totalPages'] ?? page}') ?? page,
      );
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    } catch (error) {
      if (error is DataFailure) rethrow;
      throw const DataFailure(
        'Could not load service reports. Check your connection and try again.',
      );
    }
  }

  // ---------------------------------------------------------------- checkups

  /// No `GET /checkups` on the server — checkups are session-local until the
  /// backend adds them. Starts empty so new accounts see an honest empty
  /// state; requests made this session are kept in [_checkups].
  Future<List<CheckupAppointment>> fetchCheckups() async =>
      List<CheckupAppointment>.unmodifiable(_checkups);

  // ----------------------------------------------------------------- account

  Future<Customer> fetchCustomer() async {
    // Live VPS profile endpoints (auth required). Throws [DataFailure] when
    // the server can't return a profile — no fake customer fallback.
    for (final path in ['/auth/me', '/users/me']) {
      try {
        final raw = await _api.get(path);
        final user = extractUserMap(raw);
        if (user != null) return Customer.fromJson(user);
      } on ApiException catch (error) {
        if (error.statusCode == 404) continue;
        throw DataFailure(error.message);
      } catch (_) {
        throw const DataFailure(
          'Could not reach the server. Check your connection and try again.',
        );
      }
    }
    throw const DataFailure('Could not load your profile. Please try again.');
  }

  /// Service locations (addresses) are stored on the backend under
  /// `/customers/me/addresses`. Guests keep a session-local list.
  final List<ServiceAddress> _addresses = <ServiceAddress>[];
  final List<CheckupAppointment> _checkups = <CheckupAppointment>[];

  Future<List<ServiceAddress>> fetchAddresses() async {
    if (!_api.hasToken) {
      return List<ServiceAddress>.unmodifiable(_addresses);
    }
    try {
      final raw = await _api.get('/customers/me/addresses');
      final rows = _asList(raw);
      final parsed = rows.map(ServiceAddress.fromJson).toList();
      _addresses
        ..clear()
        ..addAll(parsed);
      if (_addresses.isNotEmpty && !_addresses.any((a) => a.isDefault)) {
        _addresses[0] = _addresses[0].copyWith(isDefault: true);
      }
      return List<ServiceAddress>.unmodifiable(_addresses);
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    } catch (_) {
      return List<ServiceAddress>.unmodifiable(_addresses);
    }
  }

  Future<List<ServiceAddress>> fetchServiceLocations() => fetchAddresses();

  Future<void> saveAddress({
    String? id,
    required String label,
    String? lines,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? contactPerson,
    String? contactNumber,
    String? instructions,
  }) async {
    final addressLine = (lines ?? address ?? '').trim();
    final cityValue = (city != null && city.trim().isNotEmpty)
        ? city.trim()
        : (addressLine.isNotEmpty ? addressLine : 'NA');
    final stateValue = (state != null && state.trim().isNotEmpty)
        ? state.trim()
        : (addressLine.isNotEmpty ? addressLine : 'NA');
    final pincodeValue = (pincode != null && pincode.trim().isNotEmpty)
        ? pincode.trim()
        : '000000';

    final icon = label.toLowerCase() == 'home'
        ? Icons.home_outlined
        : Icons.apartment_outlined;

    if (!_api.hasToken) {
      final existingIndex = id == null
          ? -1
          : _addresses.indexWhere((a) => a.id == id);
      final existing = existingIndex < 0 ? null : _addresses[existingIndex];
      final local = ServiceAddress(
        id: existing?.id ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
        label: label.trim(),
        lines: addressLine,
        icon: icon,
        isDefault: existing?.isDefault ?? _addresses.isEmpty,
        city: cityValue,
        state: stateValue,
        pincode: pincodeValue,
        contactPerson: contactPerson,
        contactNumber: contactNumber,
        instructions: instructions,
      );
      if (existingIndex < 0) {
        _addresses.add(local);
      } else {
        _addresses[existingIndex] = local;
      }
      return;
    }

    final body = <String, dynamic>{
      'locationName': label.trim(),
      'address': addressLine,
      'city': cityValue,
      'state': stateValue,
      'pincode': pincodeValue,
      if (contactPerson != null && contactPerson.trim().isNotEmpty)
        'contactPerson': contactPerson.trim(),
      if (contactNumber != null && contactNumber.trim().isNotEmpty)
        'contactNumber': contactNumber.trim(),
      if (instructions != null && instructions.trim().isNotEmpty)
        'instructions': instructions.trim(),
    };

    final isCreate = id == null || id.startsWith('addr_');
    try {
      if (isCreate) {
        final raw = await _api.post('/customers/me/addresses', body: body);
        final created = raw is Map<String, dynamic>
            ? (raw['data'] is Map<String, dynamic>
                  ? raw['data'] as Map<String, dynamic>
                  : raw)
            : null;
        final parsed = created != null
            ? ServiceAddress.fromJson(created)
            : ServiceAddress(
                id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
                label: label.trim(),
                lines: addressLine,
                icon: icon,
                isDefault: _addresses.isEmpty,
                city: cityValue,
                state: stateValue,
                pincode: pincodeValue,
                contactPerson: contactPerson,
                contactNumber: contactNumber,
                instructions: instructions,
              );
        _addresses.insert(0, parsed);
      } else {
        final raw = await _api.patch('/customers/me/addresses/$id', body: body);
        final updated = raw is Map<String, dynamic>
            ? (raw['data'] is Map<String, dynamic>
                  ? raw['data'] as Map<String, dynamic>
                  : raw)
            : null;
        final parsed = updated != null
            ? ServiceAddress.fromJson(updated)
            : null;
        final index = _addresses.indexWhere((a) => a.id == id);
        if (parsed != null) {
          if (index >= 0) {
            _addresses[index] = parsed;
          } else {
            _addresses.add(parsed);
          }
        } else if (index >= 0) {
          _addresses[index] = _addresses[index].copyWith(
            label: label.trim(),
            lines: addressLine,
            city: cityValue,
            state: stateValue,
            pincode: pincodeValue,
            contactPerson: contactPerson,
            contactNumber: contactNumber,
            instructions: instructions,
          );
        }
      }
    } on ApiException catch (error) {
      throw DataFailure(error.message);
    }
  }

  Future<void> saveServiceLocation({
    String? id,
    required String label,
    required String address,
    String? city,
    String? state,
    String? pincode,
    String? contactPerson,
    String? contactNumber,
    String? instructions,
  }) => saveAddress(
    id: id,
    label: label,
    address: address,
    city: city,
    state: state,
    pincode: pincode,
    contactPerson: contactPerson,
    contactNumber: contactNumber,
    instructions: instructions,
  );

  Future<void> setDefaultAddress(String id) async {
    for (var i = 0; i < _addresses.length; i++) {
      final address = _addresses[i];
      _addresses[i] = address.copyWith(isDefault: address.id == id);
    }
  }

  Future<void> deleteAddress(String id) async {
    if (_api.hasToken) {
      try {
        await _api.delete('/customers/me/addresses/$id');
      } on ApiException catch (error) {
        throw DataFailure(error.message);
      }
    }
    _addresses.removeWhere((address) => address.id == id);
  }

  Future<void> deleteServiceLocation(String id) => deleteAddress(id);

  Future<List<CheckupAppointment>> fetchCheckupsLocal() async =>
      fetchCheckups();

  Future<CheckupAppointment> requestCheckup({
    required String dateLabel,
    required String slotLabel,
    required String address,
  }) async {
    final appointment = CheckupAppointment(
      id: 'chk_${DateTime.now().millisecondsSinceEpoch % 10000}',
      dateLabel: dateLabel,
      slotLabel: slotLabel,
      engineerName: '',
      address: address,
      isCompleted: false,
    );
    _checkups.insert(0, appointment);
    return appointment;
  }
}
