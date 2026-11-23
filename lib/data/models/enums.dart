import 'package:flutter/material.dart';

/// Availability of a staff member. Only [StaffAvailability.available] can be
/// selected as a transfer target (spec §3).
enum StaffAvailability {
  available('Available'),
  busy('Busy'),
  onLeave('On Leave'),
  offline('Offline');

  const StaffAvailability(this.label);
  final String label;

  bool get isSelectable => this == StaffAvailability.available;

  Color get color => switch (this) {
    StaffAvailability.available => const Color(0xFF17693F),
    StaffAvailability.busy => const Color(0xFFA86A08),
    StaffAvailability.onLeave => const Color(0xFF7A4FC0),
    StaffAvailability.offline => const Color(0xFF7B8C84),
  };

  Color get background => switch (this) {
    StaffAvailability.available => const Color(0xFFE8F3E6),
    StaffAvailability.busy => const Color(0xFFFDF1DC),
    StaffAvailability.onLeave => const Color(0xFFF0E9FB),
    StaffAvailability.offline => const Color(0xFFEDF3EF),
  };

  IconData get icon => switch (this) {
    StaffAvailability.available => Icons.check_circle_rounded,
    StaffAvailability.busy => Icons.pending_rounded,
    StaffAvailability.onLeave => Icons.beach_access_rounded,
    StaffAvailability.offline => Icons.cloud_off_rounded,
  };
}

/// Priority of a work order (spec §1).
enum WorkPriority {
  low('Low'),
  medium('Medium'),
  high('High'),
  urgent('Urgent');

  const WorkPriority(this.label);
  final String label;

  Color get color => switch (this) {
    WorkPriority.low => const Color(0xFF2C7A4B),
    WorkPriority.medium => const Color(0xFF1B6FC4),
    WorkPriority.high => const Color(0xFFA86A08),
    WorkPriority.urgent => const Color(0xFFC0392B),
  };

  Color get background => switch (this) {
    WorkPriority.low => const Color(0xFFE4F3E9),
    WorkPriority.medium => const Color(0xFFE4F0FB),
    WorkPriority.high => const Color(0xFFFDF1DC),
    WorkPriority.urgent => const Color(0xFFFDECEA),
  };
}

/// Employee work lifecycle (spec §9).
///
/// There is deliberately **no** "rejected by employee" state — assigned work
/// can only be progressed or transferred.
enum WorkStatus {
  assigned('ASSIGNED'),
  accepted('ACCEPTED'),
  inProgress('IN PROGRESS'),
  awaitingReport('AWAITING REPORT'),
  completed('COMPLETED'),

  // Transfer branch.
  transferRequested('TRANSFER REQUESTED'),
  managerReview('MANAGER REVIEW'),
  transferred('TRANSFERRED');

  const WorkStatus(this.label);
  final String label;

  bool get isActive =>
      this == WorkStatus.accepted || this == WorkStatus.inProgress;

  /// True while the work is still open for the assigned technician.
  bool get isOpen =>
      this != WorkStatus.completed && this != WorkStatus.transferred;

  /// True when the work is parked awaiting a transfer decision.
  bool get inTransferBranch =>
      this == WorkStatus.transferRequested || this == WorkStatus.managerReview;

  Color get color => switch (this) {
    WorkStatus.assigned => const Color(0xFF1B6FC4),
    WorkStatus.accepted => const Color(0xFF7A4FC0),
    WorkStatus.inProgress => const Color(0xFF0F766E),
    WorkStatus.awaitingReport => const Color(0xFFA86A08),
    WorkStatus.completed => const Color(0xFF2C7A4B),
    WorkStatus.transferRequested => const Color(0xFFA86A08),
    WorkStatus.managerReview => const Color(0xFFA86A08),
    WorkStatus.transferred => const Color(0xFF3D4C44),
  };

  Color get background => switch (this) {
    WorkStatus.assigned => const Color(0xFFE4F0FB),
    WorkStatus.accepted => const Color(0xFFF0E9FB),
    WorkStatus.inProgress => const Color(0xFFE0F2F0),
    WorkStatus.awaitingReport => const Color(0xFFFDF1DC),
    WorkStatus.completed => const Color(0xFFE4F3E9),
    WorkStatus.transferRequested => const Color(0xFFFDF1DC),
    WorkStatus.managerReview => const Color(0xFFFDF1DC),
    WorkStatus.transferred => const Color(0xFFEDF3EF),
  };
}

enum ReportReviewStatus {
  notSubmitted('Not Submitted'),
  draft('Draft'),
  pendingReview('Pending Review'),
  correctionRequired('Correction Required'),
  approved('Approved');

  const ReportReviewStatus(this.label);
  final String label;
}

/// Transfer request lifecycle (spec §6).
enum TransferStatus {
  transferRequested('Transfer Requested'),
  transferApproved('Transfer Approved'),
  transferred('Transferred'),
  transferRejected('Transfer Rejected');

  const TransferStatus(this.label);
  final String label;

  bool get isPending => this == TransferStatus.transferRequested;

  Color get color => switch (this) {
    TransferStatus.transferRequested => const Color(0xFFA86A08),
    TransferStatus.transferApproved => const Color(0xFF1B6FC4),
    TransferStatus.transferred => const Color(0xFF2C7A4B),
    TransferStatus.transferRejected => const Color(0xFFC0392B),
  };

  Color get background => switch (this) {
    TransferStatus.transferRequested => const Color(0xFFFDF1DC),
    TransferStatus.transferApproved => const Color(0xFFE4F0FB),
    TransferStatus.transferred => const Color(0xFFE4F3E9),
    TransferStatus.transferRejected => const Color(0xFFFDECEA),
  };
}

/// Attendance states (spec §15).
enum AttendanceStatus {
  notCheckedIn('Not Checked In'),
  present('Present'),
  late('Late'),
  halfDay('Half Day'),
  leave('Leave'),
  absent('Absent'),
  checkedOut('Checked Out');

  const AttendanceStatus(this.label);
  final String label;

  Color get color => switch (this) {
    AttendanceStatus.notCheckedIn => const Color(0xFF7B8C84),
    AttendanceStatus.present => const Color(0xFF17693F),
    AttendanceStatus.late => const Color(0xFFA86A08),
    AttendanceStatus.halfDay => const Color(0xFFA86A08),
    AttendanceStatus.leave => const Color(0xFF7A4FC0),
    AttendanceStatus.absent => const Color(0xFFC0392B),
    AttendanceStatus.checkedOut => const Color(0xFF17693F),
  };

  Color get background => switch (this) {
    AttendanceStatus.notCheckedIn => const Color(0xFFEDF3EF),
    AttendanceStatus.present => const Color(0xFFE8F3E6),
    AttendanceStatus.late => const Color(0xFFFDF1DC),
    AttendanceStatus.halfDay => const Color(0xFFFDF1DC),
    AttendanceStatus.leave => const Color(0xFFF0E9FB),
    AttendanceStatus.absent => const Color(0xFFFDECEA),
    AttendanceStatus.checkedOut => const Color(0xFFE8F3E6),
  };
}
