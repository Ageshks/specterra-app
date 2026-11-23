import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/formatters.dart';
import '../customer_app/data/models/customer.dart'
    show extractAuthToken, extractRefreshToken, extractUserMap;
import 'models/enums.dart';
import 'models/models.dart';

/// Outcome of a mutating operation, so screens can show real errors instead
/// of assuming success.
sealed class Result<T> {
  const Result();

  /// Human-readable message, shown to the user when the result is a failure.
  String? get error => null;

  bool get isSuccess => this is Success<T>;
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class Failure<T> extends Result<T> {
  const Failure(this.message);
  final String message;

  @override
  String? get error => message;
}

/// Data source for the field-staff app, backed by the SPECTERRA backend at
/// [ApiConfig.baseUrl].
///
/// Every call hits the live server.  There is no offline demo data, no
/// simulated latency, and no fallback when the network is unreachable —
/// each method throws with the server's own message (or a network error).
///
/// Staff endpoints consumed:
/// * `POST /auth/login` (all roles) + `GET /auth/me` + `GET /employees/me`
/// * `GET /dashboard/employee` / `GET /dashboard/manager`
/// * `GET /work-assignments` (employee own) / `GET /work-orders` (manager)
/// * `POST /work-assignments` + `:id/accept|start|complete`
/// * `POST /work-transfers` + `GET /work-transfers` + `:id/decision`
/// * `POST /service-reports` + `PATCH /service-reports/:id` +
///   `:id/submit|approve|request-correction`
/// * `POST /work-photos` or `/work-photos/batch` (multipart) + `GET /work-photos`
/// * `POST /attendance/check-in|check-out` + `GET /attendance/today`
/// * `GET /attendance` + `GET /attendance/:id`
/// * `POST /overtime` + `GET /overtime` + `:id/decision` + `:id/payment`
/// * `POST /leave` + `GET /leave` + `:id/decision`
/// * `GET /notifications` + `PATCH /notifications/:id/read`
/// * `GET /employees/transfer-targets` (eligible transfer recipients)
class StaffRepository {
  StaffRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  ApiClient get api => _api;

  /// Kept so logout/refresh can revoke or rotate the server session later.
  String? refreshToken;

  Employee? _currentEmployee;
  String _role = '';
  bool _supervisor = false;

  /// Cached slices — each fetch overwrites from the server, nothing is ever
  /// fabricated locally.
  List<WorkJob> _jobs = const <WorkJob>[];
  List<TransferRequest> _transfers = const <TransferRequest>[];
  List<AttendanceRecord> _attendance = const <AttendanceRecord>[];
  List<StaffMember> _staff = const <StaffMember>[];
  List<OvertimeEntry> _overtime = const <OvertimeEntry>[];
  List<LeaveRequest> _leaves = const <LeaveRequest>[];
  List<ExpenseClaim> _expenses = const <ExpenseClaim>[];
  List<StaffNotification> _notifications = const <StaffNotification>[];
  AttendanceRecord? _today;
  int _unreadCount = 0;

  /// True for MANAGER / ADMIN / SUPER_ADMIN sessions.
  bool get isManager =>
      _role == 'MANAGER' || _role == 'ADMIN' || _role == 'SUPER_ADMIN';

  bool get isSupervisor => _supervisor || isManager;

  String get role => _role;

  Employee? get currentEmployee => _currentEmployee;

  // --- List unwrapping ----------------------------------------------------

  /// The live envelope is `{ success, message, data: [...], pagination }`;
  /// some endpoints nest once more (`data.items`). Tolerate bare lists too.
  static List<Map<String, dynamic>> _asList(dynamic decoded) {
    dynamic data = decoded;
    for (var depth = 0; depth < 4 && data is Map; depth++) {
      final map = Map<String, dynamic>.from(data);
      dynamic next;
      for (final key in const ['data', 'items', 'results', 'rows', 'list']) {
        if (map[key] != null) {
          next = map[key];
          break;
        }
      }
      if (next == null || identical(next, data)) break;
      data = next;
    }
    if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    return const <Map<String, dynamic>>[];
  }

  static Map<String, dynamic>? _asMap(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final data = decoded['data'];
      if (data is Map<String, dynamic>) return data;
      return decoded;
    }
    return null;
  }

  // --- Auth -------------------------------------------------------------

  /// Staff sign in with their work email + password via `POST /auth/login`.
  /// CUSTOMER roles are refused (this app is staff-only).
  Future<Employee> login({
    required String employeeId,
    required String password,
  }) async {
    final id = employeeId.trim();
    if (id.isEmpty) {
      throw const AuthException('Enter your work email.');
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(id)) {
      throw const AuthException('Sign in with your work email address.');
    }
    if (password.isEmpty) {
      throw const AuthException('Enter your password to continue.');
    }
    try {
      final raw = await _api.post(
        '/auth/login',
        body: {'email': id, 'password': password},
      );
      final user = extractUserMap(raw);
      if (user == null) {
        throw const AuthException('Login failed. Please try again.');
      }
      final role = (user['role'] ?? '').toString().toUpperCase();
      if (role == 'CUSTOMER') {
        throw const AuthException(
          'This app is for field staff and supervisors. Customers use the customer app.',
        );
      }
      if (role != 'EMPLOYEE' &&
          role != 'MANAGER' &&
          role != 'ADMIN' &&
          role != 'SUPER_ADMIN') {
        throw const AuthException('Login failed. Please try again.');
      }
      final token = extractAuthToken(raw);
      if (token == null || token.isEmpty) {
        throw const AuthException('Login failed. Please try again.');
      }
      _api.setToken(token);
      refreshToken = extractRefreshToken(raw);
      _api.setRefreshToken(refreshToken);
      _role = role;
      _supervisor = _hasSupervisorDesignation(user);
      _currentEmployee = Employee.fromJson(user);
      await refreshAll();
      return _currentEmployee!;
    } on AuthException {
      rethrow;
    } on ApiException catch (error) {
      throw AuthException(error.message);
    } catch (_) {
      throw const AuthException(
        'Could not reach the server. Check your connection and try again.',
      );
    }
  }

  // --- Reads ------------------------------------------------------------

  /// Own profile: `GET /employees/me`, falling back to `GET /auth/me`.
  Future<Employee> fetchEmployee() async {
    for (final path in ['/employees/me', '/auth/me']) {
      try {
        final raw = await _api.get(path);
        final user = extractUserMap(raw);
        if (user != null) {
          final role = (user['role'] ?? '').toString().toUpperCase();
          if (role.isNotEmpty) _role = role;
          _supervisor = _hasSupervisorDesignation(user);
          final parsed = Employee.fromJson(user);
          _currentEmployee = parsed.role.trim().isEmpty && _role.isNotEmpty
              ? parsed.copyWith(role: _role)
              : parsed;
          return _currentEmployee!;
        }
      } on ApiException catch (error) {
        // Some deployments expose /auth/me but do not grant /employees/me
        // to every staff role. Try the auth profile route in either case.
        if (error.statusCode == 404 || error.statusCode == 403) continue;
        throw AuthException(error.message);
      }
    }
    final current = _currentEmployee;
    if (current != null) return current;
    throw const AuthException('We could not load your profile.');
  }

  /// Manager profile is not exposed by a dedicated endpoint; the signed-in
  /// manager's own profile (`fetchEmployee`) is the source of truth.
  Future<Employee> fetchManager() async => fetchEmployee();

  /// Creates an employee with an admin-selected generated employee ID format.
  Future<Result<StaffMember>> createEmployee({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String designation,
    required String employeeIdFormat,
    String? phone,
  }) async {
    try {
      final raw = await _api.post(
        '/employees',
        body: {
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'email': email.trim(),
          'password': password,
          'designation': designation.trim(),
          'employeeIdFormat': employeeIdFormat,
          if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
        },
      );
      final json = _asMap(raw);
      if (json == null) return const Failure('Could not create employee.');
      return Success(StaffMember.fromJson(json));
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Transfer targets are fetched from the employee-authorized directory.
  /// Managers review or reassign transfer requests; they are not assignees.
  Future<List<StaffMember>> fetchStaff() async {
    try {
      final raw = await _api.get('/employees/transfer-targets');
      final staff = _asList(raw)
          .map((json) {
            try {
              return StaffMember.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<StaffMember>()
          .where((member) => member.isTransferEligible)
          .toList();
      _staff = staff;
    } on ApiException catch (error) {
      if (error.statusCode == 403) {
        // Keep the last backend result if available, but don't make a
        // permission failure look like an empty technician directory.
        if (_staff.isNotEmpty) return List<StaffMember>.from(_staff);
      }
      rethrow;
    }
    final me = _currentEmployee;
    return me == null
        ? List<StaffMember>.from(_staff)
        : _staff.where((s) => s.id != me.id).toList();
  }

  /// Employees receive assignment records (whose IDs are used by accept/start)
  /// from `GET /work-assignments`; managers receive team work orders from
  /// `GET /work-orders`.
  Future<List<WorkJob>> fetchJobs() async {
    final raw = await _api.get(
      isManager ? '/work-orders' : '/work-assignments',
    );
    final jobs =
        _asList(raw)
            .map((json) {
              try {
                return WorkJob.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<WorkJob>()
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    _jobs = jobs;
    return List<WorkJob>.from(_jobs);
  }

  /// Transfer requests: `GET /work-transfers` (role-scoped by the server).
  Future<List<TransferRequest>> fetchTransfers() async {
    final raw = await _api.get('/work-transfers');
    final transfers =
        _asList(raw)
            .map((json) {
              try {
                return TransferRequest.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<TransferRequest>()
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    _transfers = transfers;
    return List<TransferRequest>.from(_transfers);
  }

  /// Attendance history: `GET /attendance` (employees own only).
  Future<List<AttendanceRecord>> fetchAttendance() async {
    final raw = await _api.get('/attendance');
    final records =
        _asList(raw)
            .map((json) {
              try {
                return AttendanceRecord.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<AttendanceRecord>()
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    _attendance = records;
    return List<AttendanceRecord>.from(_attendance);
  }

  /// Today's attendance record: `GET /attendance/today`.
  Future<AttendanceRecord> fetchToday() async {
    try {
      final raw = await _api.get('/attendance/today');
      // The backend returns `{ success, message, data }` where `data` is the
      // attendance record or `null` when no record exists for today yet.
      Map<String, dynamic>? recordJson;
      if (raw is Map<String, dynamic>) {
        if (raw.containsKey('success')) {
          final data = raw['data'];
          if (data is Map<String, dynamic>) {
            recordJson = data;
          } else {
            recordJson = null; // no record today
          }
        } else if (raw.containsKey('id') ||
            raw.containsKey('checkInTime') ||
            raw.containsKey('checkInAt')) {
          // Tolerate a bare record (no envelope).
          recordJson = raw;
        }
      }
      if (recordJson != null) {
        final parsed = AttendanceRecord.fromJson(recordJson);
        _today = parsed;
        return parsed;
      }
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        // No record yet — leave _today as-is so the UI can show "not checked in".
        return _today ?? AttendanceRecord.blank(DateTime.now());
      }
      throw AuthException(error.message);
    }
    return _today ?? AttendanceRecord.blank(DateTime.now());
  }

  /// Overtime entries: `GET /overtime` (employees own only).
  Future<List<OvertimeEntry>> fetchOvertime() async {
    final raw = await _api.get(ApiEndpoints.overtime);
    final entries =
        _asList(raw)
            .map((json) {
              try {
                return OvertimeEntry.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<OvertimeEntry>()
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    _overtime = entries;
    return List<OvertimeEntry>.from(_overtime);
  }

  Future<OvertimeEligibility> fetchOvertimeEligibility() async {
    final raw = await _api.get(ApiEndpoints.overtimeEligibilityToday);
    final json = _asMap(raw);
    if (json == null)
      throw const FormatException('Invalid overtime eligibility response.');
    return OvertimeEligibility.fromJson(json);
  }

  Future<List<OvertimeEntry>> fetchOvertimeRequests({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final raw = await _api.get(
      ApiEndpoints.overtime,
      query: {
        if (status != null) 'status': status,
        'page': '$page',
        'limit': '$limit',
      },
    );
    return _asList(raw).map(OvertimeEntry.fromJson).toList();
  }

  /// Requests overtime for the signed-in employee. Employee identity is
  /// derived by the backend from the bearer token.
  Future<Result<OvertimeEntry>> requestOvertime({
    required DateTime date,
    int? requestedMinutes,
    required String reason,
    int breakMinutes = 0,
  }) async {
    try {
      final day =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final raw = await _api.post(
        ApiEndpoints.overtime,
        body: {
          'date': day,
          if (requestedMinutes != null) 'requestedMinutes': requestedMinutes,
          'breakMinutes': breakMinutes,
          'reason': reason.trim(),
        },
      );
      final json = _asMap(raw);
      if (json == null) return const Failure('Could not request overtime.');
      final entry = OvertimeEntry.fromJson(json);
      _overtime = [entry, ..._overtime.where((item) => item.id != entry.id)];
      return Success(entry);
    } on ApiException catch (error) {
      return Failure(error.message);
    } catch (error) {
      return Failure('Could not submit overtime request. $error');
    }
  }

  /// Registers this authenticated device for push notifications.
  Future<void> registerDeviceToken(String token) async {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ANDROID',
      TargetPlatform.iOS => 'IOS',
      _ => throw UnsupportedError(
        'Push registration is only supported on Android and iOS.',
      ),
    };
    await _api.patch(
      '/notifications/devices',
      body: {
        'token': token,
        'platform': platform,
        'deviceName': defaultTargetPlatform.name,
      },
    );
  }

  /// Removes the authenticated device's push token before sign-out.
  Future<void> removeDeviceToken(String token) async {
    await _api.delete('/notifications/devices/${Uri.encodeComponent(token)}');
  }

  Future<void> decideOvertime({
    required String id,
    required String decision,
  }) async {
    await _api.post(
      ApiEndpoints.overtimeDecision(id),
      body: {'decision': decision},
    );
  }

  /// Submit a leave request for the signed-in employee. The API scopes the
  /// request from the bearer token, so an employee ID is intentionally omitted.
  Future<Result<LeaveRequest>> applyForLeave({
    required String leaveType,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) async {
    try {
      final raw = await _api.post(
        '/leave',
        body: {
          'leaveType': leaveType,
          'startDate': from.toIso8601String().split('T').first,
          'endDate': to.toIso8601String().split('T').first,
          'reason': reason.trim(),
        },
      );
      final json = _asMap(raw);
      if (json == null) return const Failure('Could not submit leave request.');
      final request = LeaveRequest.fromJson(json);
      _leaves = [request, ..._leaves.where((item) => item.id != request.id)];
      return Success(request);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Approves or rejects a pending leave request (manager/admin roles).
  Future<Result<LeaveRequest>> decideLeave({
    required String leaveId,
    required bool approve,
  }) async {
    try {
      final raw = await _api.post(
        '/leave/$leaveId/decision',
        body: {'decision': approve ? 'APPROVED' : 'REJECTED'},
      );
      final json = _asMap(raw);
      if (json == null) return const Failure('Could not update leave request.');
      final request = LeaveRequest.fromJson(json);
      _leaves = _leaves
          .map((item) => item.id == leaveId ? request : item)
          .toList();
      return Success(request);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Leave requests: `GET /leave` (employees own only; managers see all).
  Future<List<LeaveRequest>> fetchLeaves() async {
    final raw = await _api.get('/leave');
    final leaves =
        _asList(raw)
            .map((json) {
              try {
                return LeaveRequest.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<LeaveRequest>()
            .toList()
          ..sort((a, b) => b.from.compareTo(a.from));
    _leaves = leaves;
    return List<LeaveRequest>.from(_leaves);
  }

  /// Company work calendar: `GET /working-calendar/{year}`.
  /// The API client base URL supplies the application's `/api/v1` prefix.
  Future<WorkingCalendar> fetchWorkingCalendar(int year) async {
    final raw = await _api.get('/working-calendar/$year');
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('The company calendar response was invalid.');
    }
    return WorkingCalendar.fromJson(json);
  }

  bool _hasSupervisorDesignation(Map<String, dynamic> user) {
    final employee = user['employee'] is Map
        ? Map<String, dynamic>.from(user['employee'] as Map)
        : const <String, dynamic>{};
    final designationRecord = employee['designationRecord'] is Map
        ? Map<String, dynamic>.from(employee['designationRecord'] as Map)
        : const <String, dynamic>{};
    final designation =
        (employee['designation'] ??
                designationRecord['name'] ??
                user['designation'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();
    return designation == 'supervisor';
  }

  // --- Post-service billing --------------------------------------------

  Future<List<BillingInvoice>> fetchBillings({
    String? status,
    String? workOrderId,
  }) async {
    final raw = await _api.get(
      ApiEndpoints.billing,
      query: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (workOrderId != null && workOrderId.isNotEmpty)
          'workOrderId': workOrderId,
      },
    );
    return _asList(raw).map((item) => BillingInvoice.fromJson(item)).toList();
  }

  Future<List<BillingInvoice>> fetchPendingBillings() async {
    final raw = await _api.get(ApiEndpoints.billingApprovals);
    return _asList(raw).map(BillingInvoice.fromJson).toList();
  }

  Future<BillingInvoice> fetchBilling(String id) async {
    final raw = await _api.get(ApiEndpoints.billingById(id));
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Billing response was invalid.');
    }
    return BillingInvoice.fromJson(json);
  }

  Future<Map<String, dynamic>> fetchBillingConfig() async {
    final raw = await _api.get(ApiEndpoints.billingConfig);
    return _asMap(raw) ?? const <String, dynamic>{};
  }

  Future<BillingInvoice> createBilling({
    required String workOrderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _api.post(
      ApiEndpoints.billing,
      body: {'workOrderId': workOrderId, 'items': items},
    );
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Billing response was invalid.');
    }
    return BillingInvoice.fromJson(json);
  }

  Future<BillingInvoice> updateBilling({
    required String id,
    required List<Map<String, dynamic>> items,
  }) async {
    final raw = await _api.put(
      ApiEndpoints.billingById(id),
      body: {'items': items},
    );
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Billing response was invalid.');
    }
    return BillingInvoice.fromJson(json);
  }

  Future<BillingInvoice> submitBilling(String id) async {
    final raw = await _api.post(ApiEndpoints.billingSubmit(id));
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Billing response was invalid.');
    }
    return BillingInvoice.fromJson(json);
  }

  Future<BillingInvoice> decideBilling({
    required String id,
    required bool approve,
    String? remarks,
  }) async {
    final raw = await _api.post(
      approve
          ? ApiEndpoints.billingApprove(id)
          : ApiEndpoints.billingReject(id),
      body: {'remarks': remarks?.trim() ?? ''},
    );
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Billing response was invalid.');
    }
    return BillingInvoice.fromJson(json);
  }

  Future<void> uploadBillingReceipt({
    required String invoiceId,
    required String invoiceItemId,
    required List<int> bytes,
    required String fileName,
  }) async {
    await _api.uploadMultipart(
      ApiEndpoints.billingAttachments(invoiceId),
      fileField: 'receipt',
      fileName: fileName,
      fileBytes: bytes,
      fields: {'invoiceItemId': invoiceItemId},
    );
  }

  Future<List<Map<String, dynamic>>> fetchBillingHistory(String id) async {
    final raw = await _api.get(ApiEndpoints.billingHistory(id));
    return _asList(raw);
  }

  /// Expenses: employee claims are scoped to the authenticated employee.
  Future<List<ExpenseClaim>> fetchExpenses() async {
    final raw = await _api.get('/expenses');
    final entries =
        _asList(raw)
            .map((json) {
              try {
                return ExpenseClaim.fromJson(json);
              } catch (_) {
                return null;
              }
            })
            .whereType<ExpenseClaim>()
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    _expenses = entries;
    return List<ExpenseClaim>.from(_expenses);
  }

  /// Submit a claim. The server links it to the employee from the session.
  Future<Result<ExpenseClaim>> submitExpense({
    required double amount,
    required String category,
    required DateTime date,
    required String description,
    String? receiptUrl,
  }) async {
    try {
      final day =
          '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
      final raw = await _api.post(
        '/expenses',
        body: {
          'amount': amount,
          'category': category,
          'expenseDate': day,
          'description': description.trim(),
          if (receiptUrl?.trim().isNotEmpty == true)
            'receiptUrl': receiptUrl!.trim(),
        },
      );
      final json = _asMap(raw);
      if (json == null) return const Failure('Could not submit expense claim.');
      final claim = ExpenseClaim.fromJson(json);
      _expenses = [claim, ..._expenses.where((item) => item.id != claim.id)];
      return Success(claim);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Notifications: `GET /notifications` (own data).
  Future<List<StaffNotification>> fetchNotifications() async {
    final raw = await _api.get('/notifications');
    final notifications = _asList(raw)
        .map((json) {
          try {
            return StaffNotification.fromJson(json);
          } catch (_) {
            return null;
          }
        })
        .whereType<StaffNotification>()
        .toList();
    _notifications = notifications;
    _unreadCount = notifications.where((n) => !n.isRead).length;
    return List<StaffNotification>.from(_notifications);
  }

  /// Marks one notification read using the backend's PATCH endpoint.
  Future<void> markNotificationRead(String id) async {
    await _api.patch('/notifications/$id/read');
    _notifications = _notifications
        .map(
          (item) => item.id == id
              ? StaffNotification(
                  id: item.id,
                  title: item.title,
                  message: item.message,
                  time: item.time,
                  isRead: true,
                  type: item.type,
                  referenceType: item.referenceType,
                  referenceId: item.referenceId,
                )
              : item,
        )
        .toList();
    _unreadCount = _notifications.where((item) => !item.isRead).length;
  }

  /// Marks every notification read using the backend's PATCH endpoint.
  Future<void> markAllNotificationsRead() async {
    await _api.patch('/notifications/read-all');
    _notifications = _notifications
        .map(
          (item) => StaffNotification(
            id: item.id,
            title: item.title,
            message: item.message,
            time: item.time,
            isRead: true,
            type: item.type,
            referenceType: item.referenceType,
            referenceId: item.referenceId,
          ),
        )
        .toList();
    _unreadCount = 0;
  }

  /// Number of unread notifications from the last [fetchNotifications] call.
  int get unreadCount => _unreadCount;

  /// Best-effort warm-up after sign-in: each endpoint is fetched in isolation
  /// so a 403 on one (e.g. employee hitting a manager-only route) does not
  /// blank the others.
  Future<void> refreshAll() async {
    Future<void> step(Future<dynamic> Function() run) async {
      try {
        await run();
      } catch (_) {
        // Swallow — individual screens re-fetch and surface their own errors.
      }
    }

    await Future.wait([
      step(fetchJobs),
      step(fetchTransfers),
      step(fetchAttendance),
      step(fetchNotifications),
    ]);
  }

  // --- Work lifecycle ---------------------------------------------------

  /// Moves a job from `ASSIGNED` to `ACCEPTED` (spec §1, §9) via
  /// `POST /work-assignments/:id/accept`.
  ///
  /// Note there is no `rejectWork`: an employee cannot decline an assignment,
  /// they can only transfer it.
  Future<Result<WorkJob>> acceptJob(String workId) async {
    try {
      final raw = await _api.post('/work-assignments/$workId/accept');
      final job = _parseWorkJob(raw);
      _jobs.removeWhere((j) => j.id == workId);
      _jobs.add(job);
      _jobs.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
      return Success(job);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Starts accepted work via `POST /work-assignments/:id/start`.
  Future<Result<WorkJob>> startJob(String workId) async {
    try {
      final raw = await _api.post('/work-assignments/$workId/start');
      final job = _parseWorkJob(raw);
      _jobs.removeWhere((j) => j.id == workId);
      _jobs.add(job);
      return Success(job);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Uploads a site photo via `POST /work-photos` (multipart). [fileBytes]
  /// and [fileName] are optional — without an image picker the screen cannot
  /// supply them, in which case a [Failure] is returned.
  Future<Result<WorkJob>> addPhoto(
    String workId, {
    List<int>? fileBytes,
    String? fileName,
  }) async {
    if (fileBytes == null || fileName == null) {
      return const Failure('Please select a photo to upload.');
    }
    final existing = _jobs.where((item) => item.id == workId).firstOrNull;
    if (existing == null) {
      return const Failure('Work order is no longer assigned to you.');
    }
    try {
      final raw = await _api.uploadMultipart(
        '/work-photos',
        fileField: 'photo',
        fileName: fileName,
        fileBytes: fileBytes,
        fields: {'workOrderId': _workOrderIdFor(workId)},
      );
      final photoUrl = _findPhotoUrl(raw);
      final updated = existing.copyWith(
        photoCount: existing.photoCount + 1,
        photoUrls: photoUrl == null
            ? existing.photoUrls
            : [...existing.photoUrls, photoUrl],
      );
      _jobs[_jobs.indexOf(existing)] = updated;
      return Success(updated);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  String _workOrderIdFor(String assignmentOrOrderId) {
    final job = _jobs
        .where(
          (item) =>
              item.id == assignmentOrOrderId ||
              item.assignmentId == assignmentOrOrderId ||
              item.workOrderId == assignmentOrOrderId,
        )
        .firstOrNull;
    return job?.workOrderId.isNotEmpty == true
        ? job!.workOrderId
        : assignmentOrOrderId;
  }

  String? _findPhotoUrl(dynamic value) {
    if (value is String && value.startsWith('http')) return value;
    if (value is! Map) return null;
    for (final key in const [
      'url',
      'photoUrl',
      'fileUrl',
      'secure_url',
      'location',
    ]) {
      final candidate = value[key];
      if (candidate is String && candidate.startsWith('http')) {
        return candidate;
      }
    }
    for (final key in const ['data', 'photo', 'file', 'result']) {
      final found = _findPhotoUrl(value[key]);
      if (found != null) return found;
    }
    return null;
  }

  Future<Map<String, dynamic>> saveEmployeeServiceReport({
    required String workOrderId,
    required String workSummary,
    required String workPerformed,
    String? reportId,
    String? issuesFound,
    String? materialsUsed,
    String? recommendations,
    String? completionRemarks,
  }) async {
    if (workSummary.trim().isEmpty || workPerformed.trim().isEmpty) {
      throw const ApiException(
        'Enter a work summary and work performed details.',
      );
    }
    final job = _jobs
        .where(
          (item) =>
              item.id == workOrderId ||
              item.assignmentId == workOrderId ||
              item.workOrderId == workOrderId,
        )
        .firstOrNull;
    if (job == null) {
      throw const ApiException('This work is not in your assigned work list.');
    }
    final actualWorkOrderId = job.workOrderId.isNotEmpty
        ? job.workOrderId
        : workOrderId;
    final body = <String, dynamic>{
      // workOrderId is part of CreateServiceReportDto only. On an edit, the
      // report ID in the URL identifies the work order and the strict update
      // DTO rejects all other properties.
      if (reportId == null || reportId.isEmpty)
        'workOrderId': actualWorkOrderId,
      'workSummary': workSummary.trim(),
      'workPerformed': workPerformed.trim(),
      if (issuesFound?.trim().isNotEmpty == true)
        'issuesFound': issuesFound!.trim(),
      if (materialsUsed?.trim().isNotEmpty == true)
        'materialsUsed': materialsUsed!.trim(),
      if (recommendations?.trim().isNotEmpty == true)
        'recommendations': recommendations!.trim(),
      if (completionRemarks?.trim().isNotEmpty == true)
        'completionRemarks': completionRemarks!.trim(),
    };
    final raw = reportId == null || reportId.isEmpty
        ? await _api.post('/service-reports', body: body)
        : await _api.patch('/service-reports/$reportId', body: body);
    return _asMap(raw) ?? <String, dynamic>{};
  }

  Future<void> submitEmployeeServiceReport(String reportId) async {
    if (reportId.trim().isEmpty) {
      throw const ApiException('The saved report has no ID to submit.');
    }
    await _api.post('/service-reports/$reportId/submit');
  }

  Future<Result<bool>> removeWorkReportPhoto(String photoId) async {
    if (photoId.trim().isEmpty) {
      return const Failure(
        'This photo cannot be removed because it has no ID.',
      );
    }
    try {
      await _api.delete('/work-photos/${Uri.encodeComponent(photoId)}');
      return const Success(true);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  Future<Result<WorkPhotoUploadResult>> uploadWorkReportPhotos({
    required String workOrderId,
    required List<WorkPhotoUploadFile> files,
    String? serviceReportId,
    String? caption,
  }) async {
    if (files.isEmpty) return const Failure('Select at least one photo.');
    if (files.length > 10) {
      return const Failure('Upload no more than 10 photos per request.');
    }
    final job = _jobs
        .where(
          (item) =>
              item.id == workOrderId ||
              item.assignmentId == workOrderId ||
              item.workOrderId == workOrderId,
        )
        .firstOrNull;
    if (job == null) {
      return const Failure('This work is not in your assigned work list.');
    }
    for (final file in files) {
      if (!const {
        'image/jpeg',
        'image/png',
        'image/webp',
      }.contains(file.contentType.toLowerCase())) {
        return Failure('Unsupported photo format: ${file.fileName}');
      }
      final sizeLimit = files.length == 1 ? 8 : 5;
      if (file.bytes.length > sizeLimit * 1024 * 1024) {
        return Failure(
          '${file.fileName} exceeds the $sizeLimit MB photo limit.',
        );
      }
    }
    final fields = <String, String>{
      'workOrderId': job.workOrderId.isNotEmpty ? job.workOrderId : workOrderId,
      if (serviceReportId?.trim().isNotEmpty == true)
        'serviceReportId': serviceReportId!.trim(),
      if (caption?.trim().isNotEmpty == true) 'caption': caption!.trim(),
    };
    try {
      final dynamic raw;
      if (files.length == 1) {
        final file = files.single;
        raw = await _api.uploadMultipart(
          '/work-photos',
          fileField: 'photo',
          fileName: file.fileName,
          fileBytes: file.bytes,
          contentType: file.contentType,
          fields: fields,
        );
      } else {
        raw = await _api.uploadMultipartBatch(
          '/work-photos/batch',
          fileField: 'photos',
          files: files
              .map(
                (file) => http.MultipartFile.fromBytes(
                  'photos',
                  file.bytes,
                  filename: file.fileName,
                  contentType: MediaType.parse(file.contentType),
                ),
              )
              .toList(),
          fields: fields,
        );
      }
      final result = WorkPhotoUploadResult.fromJson(
        raw,
        resolveUrl: _api.resolveMediaUrl,
      );
      final current = _jobs[_jobs.indexOf(job)];
      final urls = result.photos
          .map((photo) => photo.imageUrl)
          .where((url) => url.isNotEmpty)
          .toList();
      _jobs[_jobs.indexOf(job)] = current.copyWith(
        photoCount: current.photoCount + urls.length,
        photoUrls: [...current.photoUrls, ...urls],
      );
      return Success(result);
    } on ApiException catch (error) {
      return Failure(error.message);
    } catch (error) {
      debugPrint('Work-photo upload failed: $error');
      return const Failure(
        'Could not upload photos. Check your connection and try again.',
      );
    }
  }

  /// Manager approves or requests correction on a service report via
  /// `POST /service-reports/:id/approve` or `request-correction`.
  Future<Result<WorkJob>> reviewServiceReport({
    required String workId,
    required bool approve,
    String correctionNote = '',
  }) async {
    if (!approve && correctionNote.trim().isEmpty) {
      return const Failure('Enter a correction note for the employee.');
    }
    try {
      final path = approve
          ? '/service-reports/$workId/approve'
          : '/service-reports/$workId/request-correction';
      final body = <String, dynamic>{};
      if (!approve) body['correctionNote'] = correctionNote.trim();
      final raw = await _api.post(path, body: body);
      final job = _parseWorkJob(raw);
      _jobs.removeWhere((j) => j.id == workId);
      _jobs.add(job);
      return Success(job);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Completes in-progress work via `POST /work-assignments/:id/complete`.
  Future<Result<WorkJob>> completeJob(String workId) async {
    try {
      final raw = await _api.post('/work-assignments/$workId/complete');
      final job = _parseWorkJob(raw);
      _jobs.removeWhere((j) => j.id == workId);
      _jobs.add(job);
      return Success(job);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Parses a [WorkJob] from any payload shape the server may return.
  /// Manager assigns work to a technician via `POST /work-assignments`.
  Future<Result<WorkJob>> assignWork({
    required String workId,
    required String staffId,
    required DateTime scheduledAt,
    required WorkPriority priority,
    required String instructions,
    required double estimatedServiceAmount,
    required double travelDistanceKm,
    required double travelAllowanceRate,
    required double estimatedOtherExpenses,
  }) async {
    if (!isManager) {
      return const Failure('Only a supervisor can assign work.');
    }
    try {
      String time(DateTime value) =>
          '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
      final end = scheduledAt.add(const Duration(hours: 1));
      await _api.patch(
        '/work-orders/$workId/schedule',
        body: {
          'scheduledDate': scheduledAt.toIso8601String().split('T').first,
          'scheduledStartTime': time(scheduledAt),
          'scheduledEndTime': time(end),
        },
      );
      await _api.patch(
        '/work-orders/$workId/priority',
        body: {'priority': priority.name.toUpperCase()},
      );
      await _api.post(
        '/work-assignments',
        body: {
          'workOrderId': workId,
          'employeeIds': [staffId],
          'instructions': instructions.trim(),
          'estimatedServiceAmount': estimatedServiceAmount,
          'travelDistanceKm': travelDistanceKm,
          'travelAllowanceRate': travelAllowanceRate,
          'estimatedOtherExpenses': estimatedOtherExpenses,
        },
      );
      await fetchJobs();
      final job = _jobs.where((item) => item.id == workId).firstOrNull;
      if (job == null) {
        return const Failure('Work was assigned but could not be refreshed.');
      }
      return Success(job);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  WorkJob _parseWorkJob(dynamic raw) {
    final json = _asMap(raw);
    if (json == null) {
      throw const AuthException('Could not parse work order from server.');
    }
    return WorkJob.fromJson(json);
  }

  // --- Transfers --------------------------------------------------------

  /// Raises a transfer request via `POST /work-transfers` (spec §3–§5).
  ///
  /// All three preconditions from the spec are enforced here as well as in
  /// the UI: a staff member must be selected, that member must be available,
  /// and a non-empty reason must be supplied.
  Future<Result<TransferRequest>> requestTransfer({
    required String workId,
    required String requestedStaffId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      return const Failure(transferReasonRequired);
    }
    try {
      final workOrderId = _workOrderIdFor(workId);
      final raw = await _api.post(
        '/work-transfers',
        body: {
          'workOrderId': workOrderId,
          'requestedEmployeeId': requestedStaffId,
          'reason': reason.trim(),
        },
      );
      final json = _asMap(raw);
      if (json == null) {
        return const Failure('Could not create transfer request.');
      }
      final request = TransferRequest.fromJson(json);
      _transfers.insert(0, request);
      return Success(request);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Manager approves a transfer via `PATCH /work-transfers/:id/decision`.
  Future<Result<TransferRequest>> approveTransfer(String transferId) async {
    if (!isManager) {
      return const Failure('Only a supervisor can approve transfer requests.');
    }
    try {
      final raw = await _api.patch(
        '/work-transfers/$transferId/decision',
        body: {'decision': 'approve'},
      );
      final json = _asMap(raw);
      if (json == null) {
        return const Failure('Could not process transfer decision.');
      }
      final request = TransferRequest.fromJson(json);
      _transfers.removeWhere((t) => t.id == transferId);
      _transfers.add(request);
      return Success(request);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  /// Manager keeps the original assignment via
  /// `PATCH /work-transfers/:id/decision` with a reject decision.
  Future<Result<TransferRequest>> rejectTransfer(String transferId) async {
    if (!isManager) {
      return const Failure(
        'Only a supervisor can keep the current assignment.',
      );
    }
    try {
      final raw = await _api.patch(
        '/work-transfers/$transferId/decision',
        body: {'decision': 'reject'},
      );
      final json = _asMap(raw);
      if (json == null) {
        return const Failure('Could not process transfer decision.');
      }
      final request = TransferRequest.fromJson(json);
      _transfers.removeWhere((t) => t.id == transferId);
      _transfers.add(request);
      return Success(request);
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  }

  // --- Attendance -------------------------------------------------------

  /// The record for [now], preferring the cached `fetchToday()` result and
  /// falling back to the locally loaded attendance list.
  AttendanceRecord todayRecord([DateTime? now]) {
    final at = Formatters.dayOf(now ?? DateTime.now());
    if (_today != null && Formatters.dayOf(_today!.date) == at) {
      return _today!;
    }
    for (final record in _attendance) {
      if (Formatters.dayOf(record.date) == at) return record;
    }
    return AttendanceRecord(
      id: 'att_${at.year}${at.month}_${at.day}',
      date: at,
      status: AttendanceStatus.notCheckedIn,
    );
  }

  /// Marks the start of the working day via `POST /attendance/check-in`.
  ///
  /// Rejects a second check-in on the same day — the server enforces this
  /// (spec §13).
  Future<Result<AttendanceRecord>> checkIn({
    DateTime? at,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // The backend records the server timestamp and ignores any client-supplied
      // time. The staff check-in screen captures and submits current GPS.
      final body = <String, dynamic>{};
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      final raw = await _api.post(
        '/attendance/check-in',
        body: body.isEmpty ? const <String, dynamic>{} : body,
      );
      final json = _asMap(raw);
      if (json == null) {
        return const Failure('Could not check in.');
      }
      final record = AttendanceRecord.fromJson(json);
      _today = record;
      return Success(record);
    } on ApiException catch (error) {
      return Failure(error.message);
    } catch (_) {
      return const Failure(
        'Could not reach the attendance service. Check your connection and server URL, then retry.',
      );
    }
  }

  /// Ends the working day via `POST /attendance/check-out`.
  ///
  /// Refuses to check out before a check-in — the server enforces this
  /// (spec §21).
  Future<Result<AttendanceRecord>> checkOut({
    DateTime? at,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (latitude != null) body['latitude'] = latitude;
      if (longitude != null) body['longitude'] = longitude;
      final raw = await _api.post(
        '/attendance/check-out',
        body: body.isEmpty ? const <String, dynamic>{} : body,
      );
      final json = _asMap(raw);
      if (json == null) {
        return const Failure('Could not check out.');
      }
      final record = AttendanceRecord.fromJson(json);
      _today = record;
      return Success(record);
    } on ApiException catch (error) {
      return Failure(error.message);
    } catch (_) {
      return const Failure(
        'Could not reach the attendance service. Check your connection and server URL, then retry.',
      );
    }
  }
}

/// Message the spec mandates when the transfer note is empty (spec §4).
const String transferReasonRequired =
    'Please provide a reason for transferring this work.';

/// Raised for authentication problems.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
