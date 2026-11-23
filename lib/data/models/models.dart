import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import 'enums.dart';

/// Business rules the spec left open, resolved as named constants so product
/// can change them without touching logic.
///
/// * §5/§6 disagree about whether a transfer needs manager sign-off. This is
///   a policy switch; it defaults to **required** because §6 asks the app to
///   show "Waiting for Manager Approval" and §7 defines a manager queue.
/// * §15 lists `Late` and `Half Day` but defines no thresholds.
/// * §18 needs "expected working hours" to compute overtime, and never states
///   the value.
abstract final class AttendancePolicy {
  /// Standard shift start. Anything later than [shiftStart] plus
  /// [lateGraceMinutes] is marked `Late`.
  static const int shiftStartHour = 9;
  static const int shiftStartMinute = 0;

  /// Grace period after [shiftStartHour]:start before a day counts as late.
  static const int lateGraceMinutes = 15;

  /// Regular working day length. Overtime accrues beyond this (spec §18).
  static const double expectedHours = 8;

  /// A day shorter than this is reported as `Half Day`.
  static const double halfDayThresholdHours = 4;

  /// Scheduled time of day when a transfer needs manager approval.
  static const bool transfersRequireManagerApproval = true;
}

/// A staff member in the field team (spec §3, §7).
@immutable
class StaffMember {
  const StaffMember({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.role,
    required this.department,
    required this.availability,
    required this.assignedJobs,
    this.rating = 4.7,
    this.phone = '',
    this.avatarInitials = '',
  });

  final String id;
  final String employeeId;
  final String name;
  final String role;
  final String department;
  final StaffAvailability availability;

  /// How many jobs this person is currently carrying.
  final int assignedJobs;

  final double rating;
  final String phone;
  final String avatarInitials;

  /// Technician and temporary-staff designations can receive field-work
  /// transfers. Managers review or reassign requests, but are not assignees.
  /// Eligibility is based on [role], not the account role (usually EMPLOYEE).
  bool get isTransferEligible {
    final designation = role.trim().toLowerCase().replaceAll(
      RegExp(r'[_-]+'),
      ' ',
    );
    return designation.contains('technician') ||
        designation == 'temp' ||
        designation == 'temp staff' ||
        designation == 'temporary staff';
  }

  bool get isSelectable => isTransferEligible && availability.isSelectable;

  String get initials =>
      avatarInitials.isNotEmpty ? avatarInitials : _initialsFrom(name);

  static String _initialsFrom(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  StaffMember copyWith({StaffAvailability? availability, int? assignedJobs}) {
    return StaffMember(
      id: id,
      employeeId: employeeId,
      name: name,
      role: role,
      department: department,
      availability: availability ?? this.availability,
      assignedJobs: assignedJobs ?? this.assignedJobs,
      rating: rating,
      phone: phone,
      avatarInitials: avatarInitials,
    );
  }

  /// Builds a [StaffMember] from a backend payload.
  factory StaffMember.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : const <String, dynamic>{};
    final userValue = employee['user'] ?? json['user'];
    final user = userValue is Map
        ? Map<String, dynamic>.from(userValue)
        : const <String, dynamic>{};
    final containers = [employee, json, user];

    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        for (final container in containers) {
          final value = container[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString();
          }
        }
      }
      return fallback;
    }

    final firstName = pick(['firstName', 'first_name']).trim();
    final lastName = pick(['lastName', 'last_name']).trim();
    final nestedName = '$firstName $lastName'.trim();

    String availabilityStr = pick(['availability', 'status']);
    StaffAvailability availability = StaffAvailability.available;
    for (final a in StaffAvailability.values) {
      if (availabilityStr.toUpperCase().contains(a.name.toUpperCase())) {
        availability = a;
        break;
      }
    }
    final designation = pick(['designation', 'jobTitle', 'job_title', 'title']);

    return StaffMember(
      id: pick(['id', '_id']),
      employeeId: pick([
        'employeeId',
        'employee_id',
        'employeeCode',
        'employee_code',
        'code',
        'employeeNumber',
        'employeeNo',
      ]),
      name: pick([
        'name',
        'fullName',
        'full_name',
      ], nestedName.isEmpty ? 'Staff Member' : nestedName),
      role: designation.isNotEmpty ? designation : pick(['role']),
      department: pick(['department', 'dept']),
      availability: availability,
      assignedJobs:
          int.tryParse(pick(['assignedJobs', 'assigned_jobs', 'jobCount'])) ??
          0,
      rating: double.tryParse(pick(['rating'])) ?? 4.7,
      phone: pick(['phone', 'phoneNumber', 'phone_number', 'mobile']),
      avatarInitials: pick(['avatarInitials', 'avatar_initials', 'initials']),
    );
  }
}

/// The signed-in employee.
@immutable
class Employee {
  const Employee({
    required this.id,
    required this.employeeId,
    required this.name,
    required this.role,
    required this.department,
    required this.phone,
    required this.email,
    required this.initials,
    required this.joiningDate,
  });

  final String id;
  final String employeeId;
  final String name;
  final String role;
  final String department;
  final String phone;
  final String email;
  final String initials;
  final String joiningDate;

  String get firstName => name.split(' ').first;

  Employee copyWith({String? role}) => Employee(
    id: id,
    employeeId: employeeId,
    name: name,
    role: role ?? this.role,
    department: department,
    phone: phone,
    email: email,
    initials: initials,
    joiningDate: joiningDate,
  );

  /// Builds an [Employee] from a backend payload. Accepts both camelCase and
  /// snake_case keys so the app tolerates either API convention.
  /// The live API splits names into `firstName` / `lastName` and returns
  /// the employee id inside a nested `employee` object for staff logins.
  factory Employee.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    var name = pick(['name', 'fullName', 'full_name']);
    if (name.isEmpty) {
      final first = pick(['firstName', 'first_name']);
      final last = pick(['lastName', 'last_name']);
      name = ('$first $last').trim();
    }
    // Staff logins nest employee details one level deep.
    final nested = json['employee'];
    final Map<String, dynamic> merged = nested is Map<String, dynamic>
        ? <String, dynamic>{...nested, ...json}
        : json;
    String pickMerged(List<String> keys) {
      for (final key in keys) {
        final value = merged[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return '';
    }

    return Employee(
      id: pickMerged(['id', '_id', 'userId', 'user_id']),
      employeeId: pickMerged([
        'employeeId',
        'employee_id',
        'employeeCode',
        'employee_code',
        'code',
        'employeeNumber',
        'employeeNo',
      ]),
      name: name.isEmpty ? 'Staff Member' : name,
      role: pickMerged(['role', 'designation', 'title']),
      department: pickMerged(['department', 'dept']),
      phone: pickMerged(['phone', 'phoneNumber', 'phone_number', 'mobile']),
      email: pickMerged(['email', 'emailAddress', 'email_address']),
      initials: pickMerged(['initials']).isNotEmpty
          ? pickMerged(['initials'])
          : _initialsFor(name),
      joiningDate: pickMerged([
        'joiningDate',
        'joining_date',
        'joinedOn',
        'createdAt',
      ]),
    );
  }

  static String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// A work order assigned to a field technician (spec §1, §2).
@immutable
class WorkPhoto {
  const WorkPhoto({
    this.id = '',
    required this.imageUrl,
    this.thumbnailUrl = '',
    this.caption = '',
  });

  final String id;
  final String imageUrl;
  final String thumbnailUrl;
  final String caption;

  String get previewUrl =>
      thumbnailUrl.trim().isNotEmpty ? thumbnailUrl : imageUrl;

  factory WorkPhoto.fromJson(
    Map<String, dynamic> json, {
    required String Function(String) resolveUrl,
  }) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    return WorkPhoto(
      id: pick(['id', '_id']),
      imageUrl: resolveUrl(
        pick(['imageUrl', 'url', 'photoUrl', 'fileUrl', 'secure_url']),
      ),
      thumbnailUrl: resolveUrl(
        pick(['thumbnailUrl', 'thumbnail_url', 'thumbnail']),
      ),
      caption: pick(['caption']),
    );
  }
}

class WorkPhotoUploadFile {
  const WorkPhotoUploadFile({
    required this.fileName,
    required this.bytes,
    required this.contentType,
  });

  final String fileName;
  final List<int> bytes;
  final String contentType;
}

class WorkPhotoUploadFailure {
  const WorkPhotoUploadFailure({required this.fileName, required this.message});

  final String fileName;
  final String message;
}

class WorkPhotoUploadResult {
  const WorkPhotoUploadResult({
    this.photos = const <WorkPhoto>[],
    this.failures = const <WorkPhotoUploadFailure>[],
  });

  final List<WorkPhoto> photos;
  final List<WorkPhotoUploadFailure> failures;

  factory WorkPhotoUploadResult.fromJson(
    dynamic response, {
    required String Function(String) resolveUrl,
  }) {
    dynamic data = response;
    if (data is Map && data['data'] != null) data = data['data'];
    final uploaded = <WorkPhoto>[];
    final failures = <WorkPhotoUploadFailure>[];

    Map<String, dynamic> asMap(dynamic value) =>
        value is Map ? Map<String, dynamic>.from(value) : {};
    String fileNameOf(Map<String, dynamic> map) =>
        (map['fileName'] ??
                map['filename'] ??
                map['originalName'] ??
                map['originalname'] ??
                map['file'] ??
                map['name'] ??
                '')
            .toString();
    String errorOf(Map<String, dynamic> map) {
      final error = map['message'] ?? map['error'] ?? map['reason'];
      if (error is Map) {
        return (error['message'] ?? error['error'] ?? 'Upload failed')
            .toString();
      }
      return error?.toString() ?? 'Upload failed';
    }

    void addPhoto(dynamic value) {
      final map = asMap(value);
      if (map.isEmpty) return;
      final photoMap = asMap(map['photo']).isNotEmpty
          ? asMap(map['photo'])
          : asMap(map['workPhoto']).isNotEmpty
          ? asMap(map['workPhoto'])
          : asMap(map['data']).isNotEmpty
          ? asMap(map['data'])
          : map;
      final photo = WorkPhoto.fromJson(photoMap, resolveUrl: resolveUrl);
      if (photo.imageUrl.isNotEmpty) uploaded.add(photo);
    }

    void addFailure(dynamic value) {
      final map = asMap(value);
      failures.add(
        WorkPhotoUploadFailure(
          fileName: fileNameOf(map),
          message: errorOf(map),
        ),
      );
    }

    if (data is List) {
      for (final item in data) {
        final map = asMap(item);
        if (map['success'] == false || map['error'] != null) {
          addFailure(map);
        } else {
          addPhoto(map);
        }
      }
    } else if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final photos =
          map['photos'] ??
          map['uploadedPhotos'] ??
          map['uploadedFiles'] ??
          map['successes'] ??
          map['successful'] ??
          map['uploaded'] ??
          map['files'] ??
          map['workPhoto'] ??
          map['photo'];
      final failed = map['failures'] ?? map['failedFiles'] ?? map['failed'];
      if (photos is List) {
        for (final photo in photos) {
          addPhoto(photo);
        }
      } else if (photos != null) {
        addPhoto(photos);
      }
      if (failed is List) {
        for (final failure in failed) {
          addFailure(failure);
        }
      } else if (failed is Map) {
        for (final entry in failed.entries) {
          final value = entry.value;
          addFailure(
            value is Map
                ? {'fileName': entry.key, ...Map<String, dynamic>.from(value)}
                : {'fileName': entry.key, 'message': value},
          );
        }
      } else if (failed != null) {
        addFailure(failed);
      }
      final errors = map['errors'];
      if (errors is List) {
        for (final failure in errors) {
          addFailure(failure);
        }
      } else if (errors is Map) {
        for (final entry in errors.entries) {
          final value = entry.value;
          addFailure(
            value is Map
                ? {'fileName': entry.key, ...Map<String, dynamic>.from(value)}
                : {'fileName': entry.key, 'message': value},
          );
        }
      }
      final results = map['results'];
      if (results is List) {
        for (final item in results) {
          final itemMap = asMap(item);
          if (itemMap['success'] == false || itemMap['error'] != null) {
            addFailure(itemMap);
          } else {
            addPhoto(itemMap);
          }
        }
      }
      if (photos == null &&
          failed == null &&
          errors == null &&
          (map['imageUrl'] != null ||
              map['url'] != null ||
              map['photoUrl'] != null)) {
        addPhoto(map);
      }
    }
    return WorkPhotoUploadResult(photos: uploaded, failures: failures);
  }
}

class ServiceReport {
  const ServiceReport({
    this.id = '',
    this.status = '',
    this.workSummary = '',
    this.workPerformed = '',
    this.issuesFound = '',
    this.materialsUsed = '',
    this.recommendations = '',
    this.completionRemarks = '',
    this.correctionNote = '',
    this.reviewResult = '',
    this.photos = const <WorkPhoto>[],
  });

  final String id;
  final String status;
  final String workSummary;
  final String workPerformed;
  final String issuesFound;
  final String materialsUsed;
  final String recommendations;
  final String completionRemarks;
  final String correctionNote;
  final String reviewResult;
  final List<WorkPhoto> photos;

  bool get canEdit {
    final normalized = status.toUpperCase().replaceAll(RegExp(r'[_ -]'), '');
    return normalized == 'DRAFT' || normalized == 'CORRECTIONREQUIRED';
  }

  factory ServiceReport.fromJson(
    Map<String, dynamic> json, {
    required String Function(String) resolveUrl,
  }) {
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = json[key]?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final rawPhotos = json['photos'];
    final photos = rawPhotos is List
        ? rawPhotos
              .map(
                (photo) => photo is Map
                    ? WorkPhoto.fromJson(
                        Map<String, dynamic>.from(photo),
                        resolveUrl: resolveUrl,
                      )
                    : photo is String
                    ? WorkPhoto(imageUrl: resolveUrl(photo))
                    : null,
              )
              .whereType<WorkPhoto>()
              .where((photo) => photo.imageUrl.isNotEmpty)
              .toList()
        : const <WorkPhoto>[];
    return ServiceReport(
      id: pick(['id', '_id', 'serviceReportId']),
      status: pick([
        'status',
        'reportStatus',
        'reportReviewStatus',
        'reviewStatus',
      ]),
      workSummary: pick(['workSummary', 'summary', 'content']),
      workPerformed: pick(['workPerformed', 'findings']),
      issuesFound: pick(['issuesFound']),
      materialsUsed: pick(['materialsUsed']),
      recommendations: pick(['recommendations']),
      completionRemarks: pick(['completionRemarks']),
      correctionNote: pick([
        'correctionNote',
        'reviewNote',
        'managerCorrectionNote',
      ]),
      reviewResult: pick([
        'reviewResult',
        'reviewComment',
        'managerReview',
        'managerReviewResult',
      ]),
      photos: photos,
    );
  }
}

class WorkJob {
  const WorkJob({
    required this.id,
    required this.customerName,
    required this.companyName,
    required this.serviceType,
    required this.location,
    required this.contactNumber,
    required this.scheduledAt,
    this.assignedAt,
    required this.priority,
    required this.managerInstructions,
    required this.status,
    required this.assignedTo,
    this.assignmentId = '',
    this.workOrderId = '',
    this.managerName = '',
    this.managerPhone = '',
    this.latitude,
    this.longitude,
    this.transferRequestedTo,
    this.photoCount = 0,
    this.serviceReport = '',
    this.report,
    this.reportReviewStatus = ReportReviewStatus.notSubmitted,
    this.correctionNote = '',
    this.reportReviewResult = '',
    this.baseServiceAmount = 0,
    this.gstRate,
    this.gstInclusive = false,
    this.isBillable = false,
    this.photoUrls = const <String>[],
  });

  final String id;
  final String customerName;
  final String companyName;
  final String serviceType;
  final String location;
  final String contactNumber;
  final DateTime scheduledAt;
  final DateTime? assignedAt;
  final WorkPriority priority;
  final String managerInstructions;
  final WorkStatus status;

  /// Id of the [StaffMember] currently carrying this work.
  final String assignedTo;
  final String assignmentId;
  final String workOrderId;
  final String managerName;
  final String managerPhone;
  final double? latitude;
  final double? longitude;

  /// Id of the [StaffMember] a transfer has been requested to, if any.
  final String? transferRequestedTo;

  final int photoCount;
  final String serviceReport;
  final ServiceReport? report;
  final ReportReviewStatus reportReviewStatus;
  final String correctionNote;
  final String reportReviewResult;
  final double baseServiceAmount;
  final double? gstRate;
  final bool gstInclusive;
  final bool isBillable;
  final List<String> photoUrls;

  bool get isActive => status.isActive;
  bool get isOpen => status.isOpen;

  WorkJob copyWith({
    WorkStatus? status,
    String? assignedTo,
    DateTime? scheduledAt,
    WorkPriority? priority,
    String? managerInstructions,
    String? transferRequestedTo,
    bool clearTransferTarget = false,
    int? photoCount,
    List<String>? photoUrls,
    String? serviceReport,
    ServiceReport? report,
    ReportReviewStatus? reportReviewStatus,
    String? correctionNote,
    String? reportReviewResult,
  }) {
    return WorkJob(
      id: id,
      customerName: customerName,
      companyName: companyName,
      serviceType: serviceType,
      location: location,
      contactNumber: contactNumber,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      assignedAt: assignedAt,
      priority: priority ?? this.priority,
      managerInstructions: managerInstructions ?? this.managerInstructions,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      assignmentId: assignmentId,
      workOrderId: workOrderId,
      managerName: managerName,
      managerPhone: managerPhone,
      latitude: latitude,
      longitude: longitude,
      transferRequestedTo: clearTransferTarget
          ? null
          : (transferRequestedTo ?? this.transferRequestedTo),
      photoCount: photoCount ?? this.photoCount,
      gstRate: gstRate,
      gstInclusive: gstInclusive,
      isBillable: isBillable,
      serviceReport: serviceReport ?? this.serviceReport,
      report: report ?? this.report,
      reportReviewStatus: reportReviewStatus ?? this.reportReviewStatus,
      correctionNote: correctionNote ?? this.correctionNote,
      reportReviewResult: reportReviewResult ?? this.reportReviewResult,
      baseServiceAmount: baseServiceAmount,
      photoUrls: photoUrls ?? this.photoUrls,
    );
  }

  // -- Live backend parsing -----------------------------------------------

  /// Builds a [WorkJob] from `GET /work-assignments` (employee) or
  /// `GET /work-orders` (manager) rows.
  ///
  /// The two endpoints shape rows differently: assignments nest the order
  /// under `workOrder`, managers get the order itself. Both are tolerated.
  factory WorkJob.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> order = json;
    final nested = json['workOrder'] ?? json['work_order'] ?? json['order'];
    if (nested is Map<String, dynamic>) {
      order = <String, dynamic>{...nested, ...json};
    }

    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = order[key] ?? json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    DateTime pickDate(List<String> keys) {
      for (final key in keys) {
        final value = order[key] ?? json[key];
        if (value is String && value.isNotEmpty) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return DateTime.now();
    }

    final rawStatus = pick([
      'status',
      'state',
      'assignmentStatus',
    ]).toUpperCase();
    WorkStatus status = WorkStatus.assigned;
    if (rawStatus.contains('COMPLET')) {
      status = WorkStatus.completed;
    } else if (rawStatus.contains('PROGRESS') || rawStatus.contains('START')) {
      status = WorkStatus.inProgress;
    } else if (rawStatus.contains('ACCEPT')) {
      status = WorkStatus.accepted;
    } else if (rawStatus.contains('TRANSFERRED')) {
      status = WorkStatus.transferred;
    } else if (rawStatus.contains('MANAGER') || rawStatus.contains('REVIEW')) {
      status = WorkStatus.managerReview;
    } else if (rawStatus.contains('TRANSFER')) {
      status = WorkStatus.transferRequested;
    }

    final rawPriority = pick(['priority']).toUpperCase();
    WorkPriority priority = WorkPriority.medium;
    for (final p in WorkPriority.values) {
      if (rawPriority.contains(p.name.toUpperCase())) {
        priority = p;
        break;
      }
    }

    Map<String, dynamic> mapOf(dynamic value) => value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};

    final bookingMap = mapOf(order['booking'] ?? json['booking']);
    final customer = order['customer'] ?? json['customer'];
    final customerMap = mapOf(customer);
    final bookingCustomer = mapOf(
      bookingMap['customer'] ??
          bookingMap['customerDetails'] ??
          bookingMap['customer_details'] ??
          bookingMap['customerInfo'] ??
          bookingMap['customer_info'],
    );
    final customerUser = mapOf(customerMap['user']);
    final bookingCustomerUser = mapOf(bookingCustomer['user']);
    String phoneFrom(dynamic value) {
      const phoneKeys = [
        'contactNumber',
        'contact_number',
        'phone',
        'phoneNumber',
        'phone_number',
        'mobile',
        'mobileNumber',
        'mobile_number',
      ];
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final key in phoneKeys) {
          final phone = map[key];
          if (phone is String || phone is num) {
            final normalized = phone.toString().trim();
            if (normalized.isNotEmpty) return normalized;
          }
        }
        for (final child in map.values) {
          final phone = phoneFrom(child);
          if (phone.isNotEmpty) return phone;
        }
      } else if (value is List) {
        for (final child in value) {
          final phone = phoneFrom(child);
          if (phone.isNotEmpty) return phone;
        }
      }
      return '';
    }

    String personName(Map<String, dynamic> person) {
      final name = (person['name'] ?? person['fullName'] ?? person['full_name'])
          ?.toString()
          .trim();
      if (name != null && name.isNotEmpty) return name;
      final first = (person['firstName'] ?? person['first_name'] ?? '')
          .toString()
          .trim();
      final last = (person['lastName'] ?? person['last_name'] ?? '')
          .toString()
          .trim();
      return '$first $last'.trim();
    }

    final customerName = [
      personName(customerMap),
      personName(customerUser),
      personName(bookingCustomer),
      personName(bookingCustomerUser),
      bookingMap['customerName']?.toString() ?? '',
      bookingMap['customer_name']?.toString() ?? '',
      if (customer is! Map) customer?.toString() ?? '',
      pick(['customerName', 'customer_name']),
    ].firstWhere((name) => name.trim().isNotEmpty, orElse: () => '');
    final service = order['service'];
    final serviceMap = service is Map
        ? Map<String, dynamic>.from(service)
        : const <String, dynamic>{};
    final serviceType = service is Map<String, dynamic>
        ? (service['name']?.toString() ?? '')
        : pick([
            'serviceType',
            'service_type',
            'serviceName',
            'service_name',
            'title',
          ]);
    final explicitAssignmentId = json['assignmentId'] ?? json['assignment_id'];
    final explicitWorkOrderId = pick([
      'workOrderId',
      'work_order_id',
      'orderId',
      'order_id',
    ]);
    final nestedOrderId = nested is Map<String, dynamic>
        ? nested['id']?.toString() ?? ''
        : '';
    final assignmentId =
        explicitAssignmentId?.toString() ??
        (nestedOrderId.isNotEmpty ? json['id']?.toString() ?? '' : '');
    final workOrderId = explicitWorkOrderId.isNotEmpty
        ? explicitWorkOrderId
        : nestedOrderId.isNotEmpty
        ? nestedOrderId
        : assignmentId.isEmpty
        ? pick(['id', '_id'])
        : '';
    final manager = order['manager'] ?? json['manager'];
    final managerMap = manager is Map
        ? Map<String, dynamic>.from(manager)
        : const <String, dynamic>{};
    final managerName =
        managerMap['name']?.toString() ??
        [
          managerMap['firstName'],
          managerMap['lastName'],
        ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    final rawReport =
        order['serviceReport'] ??
        order['report'] ??
        json['serviceReport'] ??
        json['report'];
    final parsedReport = rawReport is Map
        ? ServiceReport.fromJson(
            Map<String, dynamic>.from(rawReport),
            resolveUrl: ApiConfig.resolveMediaUrl,
          )
        : null;
    final serviceReport = rawReport is Map
        ? (rawReport['content'] ??
                  rawReport['workSummary'] ??
                  rawReport['findings'] ??
                  '')
              .toString()
        : rawReport?.toString() ?? '';
    final reportStatusRaw =
        (parsedReport?.status.isNotEmpty == true
                ? parsedReport!.status
                : pick([
                    'reportReviewStatus',
                    'serviceReportStatus',
                    'reportStatus',
                  ]))
            .toUpperCase()
            .replaceAll(RegExp(r'[ _-]'), '');
    final reportReviewStatus = reportStatusRaw.contains('DRAFT')
        ? ReportReviewStatus.draft
        : reportStatusRaw.contains('CORRECTION') ||
              reportStatusRaw.contains('REJECT')
        ? ReportReviewStatus.correctionRequired
        : reportStatusRaw.contains('APPROV')
        ? ReportReviewStatus.approved
        : reportStatusRaw.contains('PENDING') ||
              reportStatusRaw.contains('SUBMITTED')
        ? ReportReviewStatus.pendingReview
        : ReportReviewStatus.notSubmitted;
    final rawPhotos =
        order['photos'] ??
        order['workPhotos'] ??
        json['photos'] ??
        json['workPhotos'] ??
        parsedReport?.photos;
    final photoUrls = rawPhotos is List
        ? rawPhotos
              .map((photo) {
                if (photo is String) {
                  return ApiConfig.resolveMediaUrl(photo);
                }
                if (photo is Map) {
                  final url =
                      (photo['imageUrl'] ??
                              photo['url'] ??
                              photo['photoUrl'] ??
                              photo['fileUrl'] ??
                              photo['secure_url'] ??
                              '')
                          .toString();
                  return ApiConfig.resolveMediaUrl(url);
                }
                if (photo is WorkPhoto) {
                  return photo.imageUrl;
                }
                return '';
              })
              .where((url) => url.isNotEmpty)
              .toList()
        : const <String>[];
    final rawLocation = order['serviceLocation'];
    final serviceLocation = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : const <String, dynamic>{};
    final rawCoordinates =
        serviceLocation['coordinates'] ??
        order['coordinates'] ??
        json['coordinates'];
    final coordinateList = rawCoordinates is List ? rawCoordinates : const [];
    double? coordinate(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    final latitude = coordinate(
      serviceLocation['latitude'] ??
          order['latitude'] ??
          json['latitude'] ??
          (coordinateList.length > 1 ? coordinateList[1] : null),
    );
    final longitude = coordinate(
      serviceLocation['longitude'] ??
          order['longitude'] ??
          json['longitude'] ??
          (coordinateList.isNotEmpty ? coordinateList[0] : null),
    );
    final locationParts = [
      serviceLocation['address'],
      serviceLocation['city'],
      serviceLocation['state'],
      serviceLocation['pincode'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();
    final location = pick([
      'location',
      'address',
      'serviceAddress',
      'siteAddress',
    ], locationParts.join(', '));
    return WorkJob(
      id: assignmentId.isNotEmpty ? assignmentId : workOrderId,
      assignmentId: assignmentId,
      workOrderId: workOrderId,
      assignedAt: DateTime.tryParse(
        pick(['assignedAt', 'assigned_at', 'createdAt']),
      ),
      managerName: managerName,
      managerPhone:
          managerMap['phone']?.toString() ??
          managerMap['phoneNumber']?.toString() ??
          '',
      latitude: latitude,
      longitude: longitude,
      customerName: customerName.isEmpty ? 'Customer' : customerName,
      companyName: pick(['companyName', 'company_name', 'company']),
      serviceType: serviceType.isEmpty ? 'Service visit' : serviceType,
      location: location,
      baseServiceAmount:
          double.tryParse(
            (serviceMap['basePrice'] ??
                        bookingMap['baseServicePrice'] ??
                        bookingMap['basePrice'])
                    ?.toString() ??
                pick(['basePrice', 'estimatedServiceAmount']),
          ) ??
          0,
      gstRate: double.tryParse(serviceMap['gstRate']?.toString() ?? ''),
      gstInclusive: serviceMap['gstInclusive'] == true,
      isBillable:
          rawStatus.contains('COMPLET') || rawStatus.contains('APPROVED'),
      contactNumber: [
        pick([
          'contactNumber',
          'contact_number',
          'customerPhone',
          'customer_phone',
          'customerPhoneNumber',
          'customer_phone_number',
          'phone',
          'phoneNumber',
          'phone_number',
          'mobile',
          'mobileNumber',
          'mobile_number',
        ]),
        phoneFrom(customerMap),
        phoneFrom(customerUser),
        phoneFrom(bookingCustomer),
        phoneFrom(bookingCustomerUser),
        phoneFrom(bookingMap['contact'] ?? bookingMap['contactDetails']),
        phoneFrom(order['serviceLocation'] ?? order['service_location']),
      ].firstWhere((phone) => phone.trim().isNotEmpty, orElse: () => ''),
      scheduledAt: pickDate([
        'scheduledAt',
        'scheduled_at',
        'scheduledDate',
        'scheduled_date',
        'slotAt',
        'createdAt',
      ]),
      priority: priority,
      managerInstructions: pick([
        'managerInstructions',
        'instructions',
        'notes',
        'description',
      ]),
      // Report review is independent from transfer/work lifecycle. Mapping a
      // rejected report to managerReview hides the technician edit/resubmit
      // action behind the transfer-pending screen.
      status:
          status == WorkStatus.completed &&
              reportReviewStatus != ReportReviewStatus.approved
          ? WorkStatus.awaitingReport
          : status,
      serviceReport: serviceReport,
      report: parsedReport,
      reportReviewStatus: reportReviewStatus,
      correctionNote: parsedReport?.correctionNote.isNotEmpty == true
          ? parsedReport!.correctionNote
          : pick(['correctionNote', 'reviewNote']),
      reportReviewResult: parsedReport?.reviewResult.isNotEmpty == true
          ? parsedReport!.reviewResult
          : pick([
              'reviewResult',
              'reviewComment',
              'managerReview',
              'managerReviewResult',
            ]),
      photoCount: photoUrls.isNotEmpty
          ? photoUrls.length
          : int.tryParse(pick(['photoCount', 'photosCount'])) ?? 0,
      photoUrls: photoUrls,
      assignedTo: pick([
        'assignedTo',
        'assigneeId',
        'employeeId',
        'technicianId',
      ]),
    );
  }
}

/// A transfer request raised by an employee (spec §5, §6).
@immutable
class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.workId,
    required this.customerName,
    required this.serviceType,
    required this.scheduledAt,
    required this.location,
    required this.originalEmployeeId,
    required this.originalEmployeeName,
    required this.requestedStaffId,
    required this.requestedStaffName,
    required this.reason,
    required this.requestedAt,
    required this.status,
    this.requiresManagerApproval = true,
    this.decidedAt,
    this.managerNote = '',
  });

  final String id;
  final String workId;
  final String customerName;
  final String serviceType;
  final DateTime scheduledAt;
  final String location;
  final String originalEmployeeId;
  final String originalEmployeeName;
  final String requestedStaffId;
  final String requestedStaffName;

  /// Mandatory free-text reason. The UI refuses to submit an empty value.
  final String reason;

  final DateTime requestedAt;
  final TransferStatus status;

  /// Policy flag resolved from [AttendancePolicy].
  final bool requiresManagerApproval;

  final DateTime? decidedAt;
  final String managerNote;

  TransferRequest copyWith({
    TransferStatus? status,
    DateTime? decidedAt,
    String? managerNote,
  }) {
    return TransferRequest(
      id: id,
      workId: workId,
      customerName: customerName,
      serviceType: serviceType,
      scheduledAt: scheduledAt,
      location: location,
      originalEmployeeId: originalEmployeeId,
      originalEmployeeName: originalEmployeeName,
      requestedStaffId: requestedStaffId,
      requestedStaffName: requestedStaffName,
      reason: reason,
      requestedAt: requestedAt,
      status: status ?? this.status,
      requiresManagerApproval: requiresManagerApproval,
      decidedAt: decidedAt ?? this.decidedAt,
      managerNote: managerNote ?? this.managerNote,
    );
  }

  /// Builds a [TransferRequest] from `GET /work-transfers` rows.
  factory TransferRequest.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    DateTime pickDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return DateTime.now();
    }

    final raw = pick([
      'status',
    ]).toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
    TransferStatus status = TransferStatus.transferRequested;
    if (raw.contains('REJECT')) {
      status = TransferStatus.transferRejected;
    } else if (raw.contains('APPROV')) {
      status = TransferStatus.transferApproved;
    } else if (raw == 'TRANSFERRED' || raw.contains('COMPLET')) {
      status = TransferStatus.transferred;
    }
    return TransferRequest(
      id: pick(['id', '_id']),
      workId: pick([
        'workOrderId',
        'work_order_id',
        'workId',
        'work_id',
        'assignmentId',
      ]),
      customerName: pick(['customerName', 'customer_name']),
      serviceType: pick(['serviceType', 'service_type', 'serviceName']),
      scheduledAt: pickDate(['scheduledAt', 'scheduled_at', 'createdAt']),
      location: pick(['location', 'address']),
      originalEmployeeId: pick([
        'originalEmployeeId',
        'requesterId',
        'employeeId',
      ]),
      originalEmployeeName: pick(['originalEmployeeName', 'requesterName']),
      requestedStaffId: pick([
        'requestedStaffId',
        'requestedEmployeeId',
        'targetEmployeeId',
        'toEmployeeId',
      ]),
      requestedStaffName: pick([
        'requestedStaffName',
        'targetEmployeeName',
        'toEmployeeName',
      ]),
      reason: pick(['reason', 'note', 'remarks', 'message']),
      requestedAt: pickDate(['requestedAt', 'requested_at', 'createdAt']),
      status: status,
      decidedAt: DateTime.tryParse(pick(['decidedAt', 'decided_at'])),
      managerNote: pick(['managerNote', 'decisionNote', 'reviewNote']),
    );
  }
}

/// One day of attendance (spec §11, §16).
@immutable
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.date,
    required this.status,
    this.checkIn,
    this.checkOut,
    this.expectedHours = AttendancePolicy.expectedHours,
    this.note = '',
    this.workingMinutes,
    this.isAutoCheckedOut = false,
  });

  /// A blank "not checked in" record for [date].
  AttendanceRecord.blank(DateTime date)
    : id =
          'att_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
      date = DateTime(date.year, date.month, date.day),
      status = AttendanceStatus.notCheckedIn,
      checkIn = null,
      checkOut = null,
      expectedHours = AttendancePolicy.expectedHours,
      note = '',
      workingMinutes = null,
      isAutoCheckedOut = false;

  final String id;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final double expectedHours;
  final String note;
  final int? workingMinutes;
  final bool isAutoCheckedOut;

  bool get isCheckedIn => checkIn != null;
  bool get isCheckedOut => checkOut != null;

  /// Hours worked so far, using [checkOut] when present and `now` otherwise.
  double workedHours({DateTime? now}) {
    final start = checkIn;
    if (start == null) return 0;
    final end = checkOut ?? now;
    if (end == null || !end.isAfter(start)) return 0;
    return end.difference(start).inMinutes / 60.0;
  }

  /// Hours beyond [expectedHours], floored at zero.
  double overtimeHours({DateTime? now}) {
    final extra = workedHours(now: now) - expectedHours;
    return extra > 0 ? extra : 0;
  }

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    DateTime? checkIn,
    DateTime? checkOut,
    String? note,
  }) {
    return AttendanceRecord(
      id: id,
      date: date,
      status: status ?? this.status,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      expectedHours: expectedHours,
      note: note ?? this.note,
      workingMinutes: workingMinutes,
      isAutoCheckedOut: isAutoCheckedOut,
    );
  }

  /// Builds an [AttendanceRecord] from `GET /attendance` rows or
  /// `GET /attendance/today`. Times arrive as ISO strings (`checkInAt`,
  /// `checkOutAt`, `checkIn`, `checkOut`).
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    DateTime? pickTime(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String && value.isNotEmpty) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    final checkIn = pickTime([
      'checkInAt',
      'check_in_at',
      'checkIn',
      'check_in',
      'checkInTime',
    ]);
    final checkOut = pickTime([
      'checkOutAt',
      'check_out_at',
      'checkOut',
      'check_out',
      'checkOutTime',
    ]);
    final rawStatus = pick([
      'status',
    ]).toUpperCase().replaceAll(RegExp(r'[\s_-]'), '');
    AttendanceStatus status;
    if (rawStatus.contains('LEAVE')) {
      status = AttendanceStatus.leave;
    } else if (rawStatus.contains('ABSENT')) {
      status = AttendanceStatus.absent;
    } else if (rawStatus.contains('HALF')) {
      status = AttendanceStatus.halfDay;
    } else if (rawStatus.contains('LATE') && checkOut == null) {
      status = AttendanceStatus.late;
    } else if (checkIn != null && checkOut != null) {
      status = AttendanceStatus.checkedOut;
    } else if (checkIn != null) {
      status = rawStatus.contains('LATE')
          ? AttendanceStatus.late
          : AttendanceStatus.present;
    } else if (rawStatus.contains('LATE')) {
      status = AttendanceStatus.late;
    } else {
      status = AttendanceStatus.notCheckedIn;
    }
    DateTime date =
        pickTime(['date', 'day', 'attendanceDate', 'createdAt']) ??
        checkIn ??
        DateTime.now();
    // The API stores attendance `date` as UTC midnight. Keep its calendar
    // date in UTC so local timezones do not shift it to the following day.
    final rawDate = pick(['date', 'day', 'attendanceDate']);
    final isDateOnlyField = rawDate.isNotEmpty;
    date = isDateOnlyField
        ? DateTime.utc(date.year, date.month, date.day)
        : DateTime(date.year, date.month, date.day);
    return AttendanceRecord(
      id: pick(['id', '_id']),
      date: date,
      status: status,
      checkIn: checkIn,
      checkOut: checkOut,
      note: pick(['note', 'remarks']),
      workingMinutes: int.tryParse(pick(['workingMinutes', 'workedMinutes'])),
      isAutoCheckedOut:
          json['isAutoCheckedOut'] == true ||
          json['autoCheckedOut'] == true ||
          json['autoCheckout'] == true ||
          (checkOut != null &&
              int.tryParse(pick(['workingMinutes', 'workedMinutes'])) == 480),
    );
  }
}

/// Overtime entry from `GET /overtime` (amounts in INR).
@immutable
class OvertimeEntry {
  const OvertimeEntry({
    required this.id,
    required this.date,
    required this.hours,
    required this.status,
    this.reason = '',
    this.amount,
    this.paymentStatus = '',
    this.paidAt,
    this.employeeId = '',
    this.employeeName = '',
    this.breakMinutes = 0,
    this.startTime,
    this.endTime,
    this.remarks = '',
    this.requestedMinutes = 0,
  });

  final String id;
  final DateTime date;
  final double hours;
  final String status;
  final String reason;
  final double? amount;
  final String paymentStatus;
  final DateTime? paidAt;
  final String employeeId;
  final String employeeName;
  final int breakMinutes;
  final DateTime? startTime;
  final DateTime? endTime;
  final String remarks;
  final int requestedMinutes;

  factory OvertimeEntry.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    double? pickDouble(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value.toDouble();
        if (value is String) return double.tryParse(value);
      }
      return null;
    }

    DateTime date = DateTime.now();
    for (final key in ['date', 'day', 'attendanceDate', 'createdAt']) {
      final value = json[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          date = parsed;
          break;
        }
      }
    }
    DateTime? paidAt;
    final rawPaid = pick(['paidAt', 'paid_at', 'paymentDate']);
    if (rawPaid.isNotEmpty) paidAt = DateTime.tryParse(rawPaid);
    final employee = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : <String, dynamic>{};
    final start = pick(['startTime', 'checkInTime']);
    final end = pick(['endTime', 'checkOutTime']);
    return OvertimeEntry(
      id: pick(['id', '_id']),
      date: date,
      hours:
          (pickDouble(['hours', 'durationHours']) ??
          ((pickDouble([
                    'durationMinutes',
                    'requestedMinutes',
                    'requestedDurationMinutes',
                    'duration',
                  ]) ??
                  0) /
              60)),
      status: pick(['status'], 'PENDING'),
      reason: pick(['reason']),
      amount: pickDouble(['amount', 'paymentAmount']),
      paymentStatus: pick(['paymentStatus', 'payment_status']),
      paidAt: paidAt,
      employeeId: pick(['employeeId'], employee['id']?.toString() ?? ''),
      employeeName: pick(
        ['employeeName', 'name'],
        [
          employee['firstName'],
          employee['lastName'],
        ].whereType<String>().where((part) => part.isNotEmpty).join(' '),
      ),
      breakMinutes: (pickDouble(['breakMinutes']) ?? 0).round(),
      startTime: DateTime.tryParse(start),
      endTime: DateTime.tryParse(end),
      remarks: pick(['rejectionRemarks', 'reviewNote', 'remarks']),
      requestedMinutes:
          (pickDouble(['requestedMinutes', 'durationMinutes']) ?? 0).round(),
    );
  }
}

/// Server eligibility for applying during the current attendance shift.
@immutable
class OvertimeEligibility {
  const OvertimeEligibility({
    required this.employeeId,
    required this.date,
    this.attendanceId = '',
    this.checkInTime,
    this.checkOutTime,
    this.eligibleAt,
    this.hasOngoingWork = false,
    this.canApply = false,
    this.existingRequest,
  });

  final String employeeId;
  final DateTime date;
  final String attendanceId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final DateTime? eligibleAt;
  final bool hasOngoingWork;
  final bool canApply;
  final OvertimeEntry? existingRequest;

  factory OvertimeEligibility.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String key) =>
        DateTime.tryParse(json[key]?.toString() ?? '');
    final request = json['existingRequest'];
    return OvertimeEligibility(
      employeeId: json['employeeId']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      attendanceId: json['attendanceId']?.toString() ?? '',
      checkInTime: parse('checkInTime'),
      checkOutTime: parse('checkOutTime'),
      eligibleAt: parse('eligibleAt'),
      hasOngoingWork: json['hasOngoingWork'] == true,
      canApply: json['canApply'] == true,
      existingRequest: request is Map
          ? OvertimeEntry.fromJson(Map<String, dynamic>.from(request))
          : null,
    );
  }
}

/// Leave request from `GET /leave`.
@immutable
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.from,
    required this.to,
    required this.reason,
    required this.status,
    this.leaveType = 'ANNUAL',
    this.employeeId = '',
    this.employeeName = '',
  });

  final String id;
  final DateTime from;
  final DateTime to;
  final String reason;
  final String status;
  final String leaveType;
  final String employeeId;
  final String employeeName;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    DateTime pickDate(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is String) {
          final parsed = DateTime.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
      return DateTime.now();
    }

    final employee = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : const <String, dynamic>{};
    final user = employee['user'] is Map
        ? Map<String, dynamic>.from(employee['user'] as Map)
        : const <String, dynamic>{};
    final name = '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim();
    return LeaveRequest(
      id: pick(['id', '_id']),
      from: pickDate(['from', 'startDate', 'start_date', 'fromDate']),
      to: pickDate(['to', 'endDate', 'end_date', 'toDate']),
      reason: pick(['reason', 'note', 'remarks']),
      status: pick(['status'], 'PENDING'),
      leaveType: pick(['leaveType', 'type'], 'ANNUAL'),
      employeeId: pick(['employeeId'], employee['id']?.toString() ?? ''),
      employeeName: name.isEmpty
          ? pick(['employeeName'], 'Staff member')
          : name,
    );
  }
}

/// Company-wide calendar settings returned by `GET /working-calendar/{year}`.
@immutable
class WorkingCalendar {
  const WorkingCalendar({
    required this.year,
    required this.startDate,
    required this.endDate,
    required this.workingWeekdays,
    required this.exceptions,
  });

  final int year;
  final String startDate;
  final String endDate;
  final Set<int> workingWeekdays;
  final List<CalendarException> exceptions;

  factory WorkingCalendar.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = json['workingWeekdays'];
    final rawExceptions = json['exceptions'];
    return WorkingCalendar(
      year: _intFromJson(json['year']),
      startDate: json['startDate']?.toString() ?? '',
      endDate: json['endDate']?.toString() ?? '',
      workingWeekdays: rawWeekdays is List
          ? rawWeekdays
                .map(_intFromJson)
                .where((day) => day >= 1 && day <= 7)
                .toSet()
          : const <int>{},
      exceptions: rawExceptions is List
          ? rawExceptions
                .whereType<Map>()
                .map(
                  (item) => CalendarException.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const <CalendarException>[],
    );
  }

  CalendarDayInfo dayInfo(DateTime date) {
    final key = _calendarDateKey(date);
    CalendarException? exception;
    for (final item in exceptions) {
      if (item.date == key) {
        exception = item;
        break;
      }
    }
    final isWorkingDay = switch (exception?.type) {
      'WORKING_DAY' => true,
      'HOLIDAY' => false,
      _ => workingWeekdays.contains(date.weekday),
    };
    return CalendarDayInfo(isWorkingDay: isWorkingDay, exception: exception);
  }
}

@immutable
class CalendarException {
  const CalendarException({
    required this.date,
    required this.type,
    required this.title,
    this.note,
  });

  final String date;
  final String type;
  final String title;
  final String? note;

  factory CalendarException.fromJson(Map<String, dynamic> json) =>
      CalendarException(
        date: _calendarDateKey(_calendarDate(json['date'])),
        type: json['type']?.toString() ?? 'HOLIDAY',
        title: json['title']?.toString() ?? 'Calendar event',
        note: json['note']?.toString(),
      );
}

@immutable
class CalendarDayInfo {
  const CalendarDayInfo({required this.isWorkingDay, this.exception});

  final bool isWorkingDay;
  final CalendarException? exception;
}

DateTime _calendarDate(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) return DateTime(1970);
  return DateTime(parsed.year, parsed.month, parsed.day);
}

String _calendarDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

int _intFromJson(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

/// A post-service bill returned by the billing API.
@immutable
class BillingInvoice {
  const BillingInvoice({
    required this.id,
    required this.workOrderId,
    required this.workOrderNumber,
    required this.customerName,
    required this.serviceName,
    required this.baseServicePrice,
    required this.discountAmount,
    required this.taxableAmount,
    required this.gstRate,
    required this.gstAmount,
    required this.cgstAmount,
    required this.sgstAmount,
    required this.igstAmount,
    required this.finalAmount,
    required this.taxInclusive,
    required this.status,
    required this.createdAt,
    required this.submittedAt,
    required this.createdBy,
    required this.createdById,
    required this.approvedBy,
    required this.rejectionReason,
    required this.items,
    required this.attachments,
  });

  final String id;
  final String workOrderId;
  final String workOrderNumber;
  final String customerName;
  final String serviceName;
  final double baseServicePrice;
  final double discountAmount;
  final double taxableAmount;
  final double gstRate;
  final double gstAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double finalAmount;
  final bool taxInclusive;
  final String status;
  final DateTime? createdAt;
  final DateTime? submittedAt;
  final String createdBy;
  final String createdById;
  final String approvedBy;
  final String? rejectionReason;
  final List<BillingLineItem> items;
  final List<BillingAttachment> attachments;

  bool get canEdit => status == 'DRAFT' || status == 'REJECTED';

  factory BillingInvoice.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(dynamic value) => value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
    String personName(dynamic value) {
      final person = mapOf(value);
      final full = [
        person['firstName'],
        person['lastName'],
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      return full.isNotEmpty ? full : (person['name']?.toString() ?? '');
    }

    List<BillingAttachment> parseAttachments(dynamic value) => value is List
        ? value
              .whereType<Map>()
              .map(
                (entry) => BillingAttachment.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .toList()
        : const <BillingAttachment>[];

    final workOrder = mapOf(json['workOrder']);
    final customer = mapOf(json['customer']);
    final customerUser = mapOf(customer['user']);
    final service = mapOf(json['service']);
    final items = json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    BillingLineItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <BillingLineItem>[];
    return BillingInvoice(
      id: json['id']?.toString() ?? '',
      workOrderId:
          workOrder['id']?.toString() ?? json['workOrderId']?.toString() ?? '',
      workOrderNumber:
          workOrder['workOrderNumber']?.toString() ??
          json['workOrderNumber']?.toString() ??
          '',
      customerName: personName(customerUser).isNotEmpty
          ? personName(customerUser)
          : (customer['name']?.toString() ?? 'Customer'),
      serviceName: service['name']?.toString() ?? '',
      baseServicePrice: _billingNumber(json['baseServicePrice']),
      discountAmount: _billingNumber(json['discountAmount']),
      taxableAmount: _billingNumber(json['taxableAmount']),
      gstRate: _billingNumber(json['gstRate'] ?? service['gstRate']),
      gstAmount: _billingNumber(json['gstAmount']),
      cgstAmount: _billingNumber(json['cgstAmount']),
      sgstAmount: _billingNumber(json['sgstAmount']),
      igstAmount: _billingNumber(json['igstAmount']),
      finalAmount: _billingNumber(json['finalAmount']),
      taxInclusive: json['taxInclusive'] == true,
      status: json['status']?.toString().toUpperCase() ?? 'DRAFT',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      submittedAt: DateTime.tryParse(json['submittedAt']?.toString() ?? ''),
      createdBy: personName(json['createdBy']),
      createdById:
          json['createdById']?.toString() ??
          mapOf(json['createdBy'])['id']?.toString() ??
          '',
      approvedBy: personName(json['approvedBy']),
      rejectionReason: json['rejectionReason']?.toString(),
      items: items,
      attachments: parseAttachments(json['attachments']),
    );
  }
}

@immutable
class BillingLineItem {
  const BillingLineItem({
    required this.id,
    required this.category,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
    required this.attachments,
  });

  final String id;
  final String category;
  final String description;
  final double quantity;
  final double unitPrice;
  final double amount;
  final List<BillingAttachment> attachments;

  factory BillingLineItem.fromJson(
    Map<String, dynamic> json,
  ) => BillingLineItem(
    id: json['id']?.toString() ?? '',
    category: json['category']?.toString() ?? 'OTHER_EXPENSE',
    description: json['description']?.toString() ?? '',
    quantity: _billingNumber(json['quantity']),
    unitPrice: _billingNumber(json['unitPrice']),
    amount: _billingNumber(json['amount']),
    attachments: json['attachments'] is List
        ? (json['attachments'] as List)
              .whereType<Map>()
              .map(
                (item) =>
                    BillingAttachment.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <BillingAttachment>[],
  );
}

@immutable
class BillingAttachment {
  const BillingAttachment({required this.id, required this.url});

  final String id;
  final String url;

  factory BillingAttachment.fromJson(Map<String, dynamic> json) =>
      BillingAttachment(
        id: json['id']?.toString() ?? '',
        url: json['fileUrl']?.toString() ?? json['url']?.toString() ?? '',
      );
}

double _billingNumber(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;

/// Employee expense claim from `GET /expenses`.
@immutable
class ExpenseClaim {
  const ExpenseClaim({
    required this.id,
    required this.amount,
    required this.category,
    required this.date,
    required this.description,
    required this.status,
    this.receiptUrl,
    this.employeeId = '',
    this.employeeNo = '',
    this.reviewNote,
  });

  final String id;
  final double amount;
  final String category;
  final DateTime date;
  final String description;
  final String status;
  final String? receiptUrl;
  final String employeeId;
  final String employeeNo;
  final String? reviewNote;

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
    final employee = json['employee'] is Map
        ? Map<String, dynamic>.from(json['employee'] as Map)
        : const <String, dynamic>{};
    DateTime date = DateTime.now();
    final rawDate = json['expenseDate'] ?? json['date'] ?? json['createdAt'];
    if (rawDate is String) date = DateTime.tryParse(rawDate) ?? date;
    double amount = 0;
    final rawAmount = json['amount'];
    if (rawAmount is num) amount = rawAmount.toDouble();
    if (rawAmount is String) amount = double.tryParse(rawAmount) ?? 0;
    String pick(String key, [String fallback = '']) =>
        json[key]?.toString() ?? fallback;
    return ExpenseClaim(
      id: pick('id', pick('_id')),
      amount: amount,
      category: pick('category', 'Other'),
      date: date,
      description: pick('description'),
      status: pick('status', 'PENDING'),
      receiptUrl: json['receiptUrl']?.toString(),
      employeeId: pick('employeeId', employee['id']?.toString() ?? ''),
      employeeNo: employee['employeeNo']?.toString() ?? '',
      reviewNote: json['reviewNote']?.toString(),
    );
  }
}

/// Push notification row from `GET /notifications`.
@immutable
class StaffNotification {
  const StaffNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
    this.type = 'GENERAL',
    this.referenceType,
    this.referenceId,
  });

  final String id;
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final String type;
  final String? referenceType;
  final String? referenceId;

  factory StaffNotification.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    var time = pick(['time', 'timeAgo']);
    final rawDate = pick(['createdAt', 'created_at', 'date']);
    if (time.isEmpty && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      time = parsed == null
          ? rawDate
          : '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    if (time.isEmpty) time = 'Recently';
    final rawRead = json['isRead'] ?? json['is_read'] ?? json['read'];
    return StaffNotification(
      id: pick(['id', '_id']),
      title: pick(['title', 'subject'], 'Notification'),
      message: pick(['message', 'body', 'description']),
      time: time,
      isRead: rawRead == true,
      type: pick(['type'], 'GENERAL'),
      referenceType: pick(['referenceType', 'reference_type']).isEmpty
          ? null
          : pick(['referenceType', 'reference_type']),
      referenceId: pick(['referenceId', 'reference_id']).isEmpty
          ? null
          : pick(['referenceId', 'reference_id']),
    );
  }
}

/// Aggregated monthly numbers for the summary cards.
/// Built from attendance records locally, or from `GET /dashboard/employee`.
@immutable
class AttendanceSummary {
  const AttendanceSummary({
    required this.workingDays,
    required this.present,
    required this.absent,
    required this.leave,
    required this.late,
    required this.overtimeHours,
  });

  final int workingDays;
  final int present;
  final int absent;
  final int leave;
  final int late;
  final double overtimeHours;

  /// Builds the employee dashboard summary from `GET /dashboard/employee`.
  factory AttendanceSummary.fromDashboard(Map<String, dynamic> json) {
    int pickInt(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
      }
      return 0;
    }

    double pickDouble(List<String> keys) {
      for (final key in keys) {
        final value = json[key];
        if (value is num) return value.toDouble();
      }
      return 0;
    }

    return AttendanceSummary(
      workingDays: pickInt(['workingDays', 'totalDays']),
      present: pickInt(['present', 'presentDays']),
      absent: pickInt(['absent', 'absentDays']),
      leave: pickInt(['leave', 'leaveDays', 'onLeave']),
      late: pickInt(['late', 'lateDays']),
      overtimeHours: pickDouble(['overtimeHours', 'overtime']),
    );
  }
  static AttendanceSummary fromRecords(List<AttendanceRecord> records) {
    var present = 0;
    var absent = 0;
    var leave = 0;
    var late = 0;
    var overtime = 0.0;

    for (final record in records) {
      switch (record.status) {
        case AttendanceStatus.present:
        case AttendanceStatus.checkedOut:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.leave:
          leave++;
        case AttendanceStatus.late:
        case AttendanceStatus.halfDay:
          late++;
        case AttendanceStatus.notCheckedIn:
          break;
      }
      overtime += record.overtimeHours();
    }

    return AttendanceSummary(
      workingDays: records.length,
      present: present,
      absent: absent,
      leave: leave,
      late: late,
      overtimeHours: overtime,
    );
  }
}
