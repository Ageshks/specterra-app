import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/session_store.dart';
import '../data/models/enums.dart';
import '../data/models/models.dart';
import '../data/staff_repository.dart';

/// Immutable snapshot the UI renders from.
@immutable
class AppData {
  const AppData({
    this.employee,
    this.manager,
    this.staff = const <StaffMember>[],
    this.jobs = const <WorkJob>[],
    this.transfers = const <TransferRequest>[],
    this.attendance = const <AttendanceRecord>[],
    this.overtime = const <OvertimeEntry>[],
    this.loading = true,
    this.busy = false,
    this.error,
    this.staffError,
  });

  final Employee? employee;
  final Employee? manager;
  final List<StaffMember> staff;
  final List<WorkJob> jobs;
  final List<TransferRequest> transfers;
  final List<AttendanceRecord> attendance;
  final List<OvertimeEntry> overtime;
  final bool loading;

  /// True while a mutation is in flight, for button spinners.
  final bool busy;

  final String? error;
  final String? staffError;

  bool get isSignedIn => employee != null;

  /// Only `Available` staff can be picked as a transfer target (spec §3).
  List<StaffMember> get availableStaff =>
      staff.where((s) => s.isSelectable).toList();

  List<WorkJob> get assignedJobs =>
      jobs.where((j) => j.status == WorkStatus.assigned).toList();

  List<WorkJob> get activeJobs =>
      jobs.where((j) => j.status == WorkStatus.inProgress).toList();

  List<WorkJob> get acceptedJobs =>
      jobs.where((j) => j.status == WorkStatus.accepted).toList();

  List<WorkJob> get completedJobs =>
      jobs.where((j) => j.status == WorkStatus.completed).toList();

  List<WorkJob> get reportReviewJobs => jobs
      .where(
        (job) =>
            job.status == WorkStatus.awaitingReport ||
            job.reportReviewStatus == ReportReviewStatus.pendingReview ||
            job.reportReviewStatus == ReportReviewStatus.correctionRequired,
      )
      .toList();

  List<WorkJob> get todayJobs {
    final now = DateTime.now();
    return jobs.where((j) {
      final d = j.scheduledAt;
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  /// Transfer requests this employee raised (spec §8).
  List<TransferRequest> get myTransfers {
    final me = employee;
    if (me == null) return const <TransferRequest>[];
    return transfers.where((t) => t.originalEmployeeId == me.id).toList();
  }

  /// Requests still awaiting a manager decision (spec §7).
  List<TransferRequest> get pendingTransfers =>
      transfers.where((t) => t.status.isPending).toList();

  AppData copyWith({
    Employee? employee,
    Employee? manager,
    List<StaffMember>? staff,
    List<WorkJob>? jobs,
    List<TransferRequest>? transfers,
    List<AttendanceRecord>? attendance,
    List<OvertimeEntry>? overtime,
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    String? staffError,
    bool clearStaffError = false,
  }) {
    return AppData(
      employee: employee ?? this.employee,
      manager: manager ?? this.manager,
      staff: staff ?? this.staff,
      jobs: jobs ?? this.jobs,
      transfers: transfers ?? this.transfers,
      attendance: attendance ?? this.attendance,
      overtime: overtime ?? this.overtime,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      staffError: clearStaffError ? null : (staffError ?? this.staffError),
    );
  }
}

/// App-wide state holder.
///
/// Every mutation funnels through here so screens stay declarative and the
/// same business rules apply no matter which surface triggers the action.
class AppController extends ChangeNotifier {
  AppController({StaffRepository? repository})
    : _repo = repository ?? StaffRepository();

  final StaffRepository _repo;
  StaffRepository get repository => _repo;
  Future<void> Function()? onStaffAuthenticated;
  Future<void> Function()? beforeStaffSignOut;
  AppData _data = const AppData();

  AppData get data => _data;

  // --- Loading ----------------------------------------------------------

  Future<void> loadSession() async {
    _emit(_data.copyWith(loading: true, clearError: true));
    // Keep the user from the successful login response while profile routes
    // hydrate. A transient /employees/me failure must not discard the valid
    // identity and strand an authenticated employee outside their dashboard.
    Employee? employee = _repo.currentEmployee;
    Employee? manager;
    String? staffError;
    List<StaffMember> staff = const <StaffMember>[];
    List<WorkJob> jobs = const <WorkJob>[];
    List<TransferRequest> transfers = const <TransferRequest>[];
    List<AttendanceRecord> attendance = const <AttendanceRecord>[];
    List<OvertimeEntry> overtime = const <OvertimeEntry>[];

    try {
      employee = await _repo.fetchEmployee();
    } catch (_) {}
    try {
      manager = await _repo.fetchManager();
    } catch (_) {}
    try {
      staff = await _repo.fetchStaff();
    } on ApiException catch (error) {
      staffError = error.message;
    } catch (_) {
      staffError = 'Could not load the staff directory. Please try again.';
    }
    try {
      jobs = await _repo.fetchJobs();
    } catch (_) {}
    try {
      transfers = await _repo.fetchTransfers();
    } catch (_) {}
    try {
      attendance = await _repo.fetchAttendance();
    } catch (_) {}
    try {
      overtime = await _repo.fetchOvertime();
    } catch (_) {}
    try {
      await _repo.fetchToday();
    } catch (_) {}
    try {
      await _repo.fetchNotifications();
    } catch (_) {}

    _emit(
      _data.copyWith(
        employee: employee,
        manager: manager,
        staff: staff,
        jobs: jobs,
        transfers: transfers,
        attendance: attendance,
        overtime: overtime,
        loading: false,
        staffError: staffError,
        clearStaffError: staffError == null,
        clearError: true,
      ),
    );
  }

  /// Refreshes the mutable slices without flashing the loading state.
  Future<void> refresh() async {
    String? staffError;
    List<StaffMember> staff = const <StaffMember>[];
    List<WorkJob> jobs = const <WorkJob>[];
    List<TransferRequest> transfers = const <TransferRequest>[];
    List<AttendanceRecord> attendance = const <AttendanceRecord>[];
    List<OvertimeEntry> overtime = const <OvertimeEntry>[];

    try {
      staff = await _repo.fetchStaff();
    } on ApiException catch (error) {
      staffError = error.message;
    } catch (_) {
      staffError = 'Could not load the staff directory. Please try again.';
    }
    try {
      jobs = await _repo.fetchJobs();
    } catch (_) {}
    try {
      transfers = await _repo.fetchTransfers();
    } catch (_) {}
    try {
      attendance = await _repo.fetchAttendance();
    } catch (_) {}
    try {
      overtime = await _repo.fetchOvertime();
    } catch (_) {}
    try {
      await _repo.fetchToday();
    } catch (_) {}
    try {
      await _repo.fetchNotifications();
    } catch (_) {}

    _emit(
      _data.copyWith(
        staff: staff,
        jobs: jobs,
        transfers: transfers,
        attendance: attendance,
        overtime: overtime,
        staffError: staffError,
        clearStaffError: staffError == null,
        clearError: true,
      ),
    );
  }

  Future<void> retry() => loadSession();

  /// Verifies credentials and refreshes the session. Field staff always sign
  /// in, so a failure here is surfaced as an [AuthException] to the login
  /// screen rather than to a global error banner.
  Future<void> repositoryLogin({
    required String employeeId,
    required String password,
  }) async {
    await _repo.login(employeeId: employeeId, password: password);
    final token = _repo.api.token;
    if (token != null && token.isNotEmpty) {
      // Persist the session so a cold start resumes without a new login.
      await SessionStore.instance.save(
        token: token,
        refreshToken: _repo.refreshToken,
        role: _repo.role,
        isStaff: true,
      );
    }
    await loadSession();
    await onStaffAuthenticated?.call();
  }

  /// Rehydrates a persisted staff session after a cold start.
  ///
  /// Returns false when there is nothing to restore or the server rejected
  /// the stored token (expired / revoked) — the caller should fall through
  /// to the welcome screen. Network failures keep the token and load what
  /// they can; shells surface their own retry state.
  Future<bool> restoreSession() async {
    final stored = await SessionStore.instance.restore();
    if (stored == null || !stored.isStaff) return false;
    _repo.api.setToken(stored.token);
    _repo.api.setRefreshToken(stored.refreshToken);
    try {
      // Validate the persisted token before hydrating the shell.
      await _repo.api.get('/auth/me');
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _repo.api.clearToken();
        await SessionStore.instance.clear();
        return false;
      }
      // Offline or server hiccup — keep the session and load what we can.
    }
    await loadSession();
    await onStaffAuthenticated?.call();
    return true;
  }

  // --- Work actions -----------------------------------------------------
  /// Accepting is the only response to an assignment (spec §1). There is no
  /// reject action by design.
  Future<Result<WorkJob>> acceptJob(String workId) =>
      _run(() => _repo.acceptJob(workId));

  Future<Result<WorkJob>> startJob(String workId) =>
      _run(() => _repo.startJob(workId));

  Future<Result<WorkJob>> addPhoto(
    String workId, {
    List<int>? fileBytes,
    String? fileName,
  }) => _run(
    () => _repo.addPhoto(workId, fileBytes: fileBytes, fileName: fileName),
  );

  Future<Result<WorkPhotoUploadResult>> uploadWorkReportPhotos({
    required String workOrderId,
    required List<WorkPhotoUploadFile> files,
    String? serviceReportId,
    String? caption,
  }) async {
    final result = await _run(
      () => _repo.uploadWorkReportPhotos(
        workOrderId: workOrderId,
        files: files,
        serviceReportId: serviceReportId,
        caption: caption,
      ),
    );
    if (result case Success<WorkPhotoUploadResult>(:final value)) {
      final jobs = List<WorkJob>.from(_data.jobs);
      final index = jobs.indexWhere(
        (job) =>
            job.id == workOrderId ||
            job.assignmentId == workOrderId ||
            job.workOrderId == workOrderId,
      );
      if (index >= 0) {
        final job = jobs[index];
        final urls = value.photos
            .map((photo) => photo.imageUrl)
            .where((url) => url.isNotEmpty && !job.photoUrls.contains(url))
            .toList();
        if (urls.isNotEmpty) {
          jobs[index] = job.copyWith(
            photoCount: job.photoCount + urls.length,
            photoUrls: [...job.photoUrls, ...urls],
          );
          _emit(_data.copyWith(jobs: jobs));
        }
      }
    }
    return result;
  }

  Future<Result<Map<String, dynamic>>> saveEmployeeServiceReport({
    required String workOrderId,
    required String workSummary,
    required String workPerformed,
    String? reportId,
    String? issuesFound,
    String? materialsUsed,
    String? recommendations,
    String? completionRemarks,
  }) => _run(() async {
    try {
      return Success(
        await _repo.saveEmployeeServiceReport(
          workOrderId: workOrderId,
          reportId: reportId,
          workSummary: workSummary,
          workPerformed: workPerformed,
          issuesFound: issuesFound,
          materialsUsed: materialsUsed,
          recommendations: recommendations,
          completionRemarks: completionRemarks,
        ),
      );
    } on ApiException catch (error) {
      return Failure(error.message);
    }
  });

  Future<Result<bool>> submitEmployeeServiceReport(String reportId) =>
      _run(() async {
        try {
          await _repo.submitEmployeeServiceReport(reportId);
          return const Success(true);
        } on ApiException catch (error) {
          return Failure(error.message);
        }
      });

  Future<Result<bool>> removeWorkReportPhoto(String photoId) =>
      _run(() => _repo.removeWorkReportPhoto(photoId));

  Future<Result<WorkJob>> reviewServiceReport({
    required String workId,
    required bool approve,
    String correctionNote = '',
  }) => _run(
    () => _repo.reviewServiceReport(
      workId: workId,
      approve: approve,
      correctionNote: correctionNote,
    ),
  );

  Future<Result<WorkJob>> completeJob(String workId) =>
      _run(() => _repo.completeJob(workId));

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
  }) => _run(
    () => _repo.assignWork(
      workId: workId,
      staffId: staffId,
      scheduledAt: scheduledAt,
      priority: priority,
      instructions: instructions,
      estimatedServiceAmount: estimatedServiceAmount,
      travelDistanceKm: travelDistanceKm,
      travelAllowanceRate: travelAllowanceRate,
      estimatedOtherExpenses: estimatedOtherExpenses,
    ),
  );

  /// Submits a transfer. Returns the created request, or a [Failure] whose
  /// message the screen surfaces directly.
  Future<Result<TransferRequest>> requestTransfer({
    required String workId,
    required String requestedStaffId,
    required String reason,
  }) {
    return _run(
      () => _repo.requestTransfer(
        workId: workId,
        requestedStaffId: requestedStaffId,
        reason: reason,
      ),
    );
  }

  Future<Result<TransferRequest>> approveTransfer(String transferId) =>
      _run(() => _repo.approveTransfer(transferId));

  Future<Result<TransferRequest>> keepAssignment(String transferId) =>
      _run(() => _repo.rejectTransfer(transferId));

  // --- Attendance -------------------------------------------------------

  Future<Result<AttendanceRecord>> checkIn({
    DateTime? at,
    double? latitude,
    double? longitude,
  }) => _runAttendance(
    () => _repo.checkIn(at: at, latitude: latitude, longitude: longitude),
  );

  Future<Result<AttendanceRecord>> checkOut({
    DateTime? at,
    double? latitude,
    double? longitude,
  }) => _runAttendance(
    () => _repo.checkOut(at: at, latitude: latitude, longitude: longitude),
  );

  Future<Result<OvertimeEntry>> requestOvertime({
    required DateTime date,
    required int requestedMinutes,
    String reason = '',
    int breakMinutes = 0,
  }) => _run(
    () => _repo.requestOvertime(
      date: date,
      requestedMinutes: requestedMinutes,
      reason: reason,
      breakMinutes: breakMinutes,
    ),
  );

  /// The record for today, synthesised when absent.
  AttendanceRecord todayRecord([DateTime? now]) => _repo.todayRecord(now);

  void clearError() => _emit(_data.copyWith(clearError: true));

  /// Clears the in-memory staff session, its loaded data and the persisted
  /// session, so the next cold start lands on the welcome screen.
  Future<void> signOut() async {
    try {
      await beforeStaffSignOut?.call();
    } finally {
      _repo.api.clearToken();
      // Best-effort; writes are serialised so this can't overtake a later save.
      await SessionStore.instance.clear();
      _emit(const AppData(loading: false));
    }
  }

  // --- Internals --------------------------------------------------------

  /// Runs a mutation with a busy flag and reloads the affected slices.
  Future<Result<T>> _run<T>(Future<Result<T>> Function() action) async {
    _emit(_data.copyWith(busy: true, clearError: true));
    try {
      final result = await action();
      if (result is Failure<T>) {
        _emit(_data.copyWith(busy: false));
        return result;
      }
      await refresh();
      if (result is Success<T> && result.value is AttendanceRecord) {
        final attendance = List<AttendanceRecord>.from(_data.attendance);
        final updated = result.value as AttendanceRecord;
        attendance.removeWhere((record) => record.id == updated.id);
        attendance.insert(0, updated);
        _emit(_data.copyWith(attendance: attendance));
      }
      _emit(_data.copyWith(busy: false));
      return result;
    } catch (_) {
      _emit(_data.copyWith(busy: false, error: 'Something went wrong.'));
      return Failure<T>('Something went wrong. Please try again.');
    }
  }

  /// Attendance endpoints return the authoritative updated record. Apply it
  /// directly so check-in/out does not wait for unrelated dashboard APIs.
  Future<Result<AttendanceRecord>> _runAttendance(
    Future<Result<AttendanceRecord>> Function() action,
  ) async {
    _emit(_data.copyWith(busy: true, clearError: true));
    try {
      final result = await action();
      if (result is Failure<AttendanceRecord>) {
        _emit(_data.copyWith(busy: false));
        return result;
      }
      final record = (result as Success<AttendanceRecord>).value;
      final attendance = List<AttendanceRecord>.from(_data.attendance)
        ..removeWhere((item) => item.id == record.id)
        ..add(record)
        ..sort((a, b) => b.date.compareTo(a.date));
      _emit(_data.copyWith(attendance: attendance, busy: false));
      return result;
    } catch (_) {
      _emit(_data.copyWith(busy: false));
      return const Failure<AttendanceRecord>(
        'Could not mark attendance. Please try again.',
      );
    }
  }

  void _emit(AppData next) {
    _data = next;
    notifyListeners();
  }
}

/// Provides [AppController] to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing from the widget tree.');
    return scope!.notifier!;
  }

  /// Reads the controller without subscribing, for one-shot callbacks.
  static AppController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppScope>()!;
    return (element.widget as AppScope).notifier!;
  }
}
