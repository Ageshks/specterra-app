import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../data/models/enums.dart';

/// Status badge that always carries a text label.
///
/// Spec §15 is explicit: never rely on colour alone, always show the status
/// as text. Every badge in this app therefore renders [text].
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    this.icon,
    this.dense = false,
  });

  /// Builds a badge straight from one of the spec's status enums.
  factory StatusBadge.work(WorkStatus status, {bool dense = false}) {
    return StatusBadge(
      text: status.label,
      color: status.color,
      background: status.background,
      icon: _workIcon(status),
      dense: dense,
    );
  }

  factory StatusBadge.priority(WorkPriority priority, {bool dense = false}) {
    return StatusBadge(
      text: priority.label,
      color: priority.color,
      background: priority.background,
      icon: priority == WorkPriority.urgent
          ? Icons.priority_high_rounded
          : null,
      dense: dense,
    );
  }

  factory StatusBadge.transfer(TransferStatus status, {bool dense = false}) {
    return StatusBadge(
      text: status.label,
      color: status.color,
      background: status.background,
      icon: _transferIcon(status),
      dense: dense,
    );
  }

  factory StatusBadge.availability(
    StaffAvailability availability, {
    bool dense = false,
  }) {
    return StatusBadge(
      text: availability.label,
      color: availability.color,
      background: availability.background,
      icon: availability.icon,
      dense: dense,
    );
  }

  factory StatusBadge.attendance(
    AttendanceStatus status, {
    bool dense = false,
  }) {
    return StatusBadge(
      text: status.label,
      color: status.color,
      background: status.background,
      icon: _attendanceIcon(status),
      dense: dense,
    );
  }

  final String text;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 14, color: color),
            SizedBox(width: dense ? 4 : 5),
          ],
          // Text is mandatory, not decorative - see the class docs.
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _workIcon(WorkStatus status) => switch (status) {
    WorkStatus.assigned => Icons.assignment_outlined,
    WorkStatus.accepted => Icons.task_alt_rounded,
    WorkStatus.inProgress => Icons.play_circle_outline_rounded,
    WorkStatus.awaitingReport => Icons.description_outlined,
    WorkStatus.completed => Icons.check_circle_rounded,
    WorkStatus.transferRequested => Icons.swap_horiz_rounded,
    WorkStatus.managerReview => Icons.hourglass_top_rounded,
    WorkStatus.transferred => Icons.alt_route_rounded,
  };

  static IconData _transferIcon(TransferStatus status) => switch (status) {
    TransferStatus.transferRequested => Icons.hourglass_top_rounded,
    TransferStatus.transferApproved => Icons.thumb_up_alt_outlined,
    TransferStatus.transferred => Icons.check_circle_rounded,
    TransferStatus.transferRejected => Icons.cancel_outlined,
  };

  static IconData _attendanceIcon(AttendanceStatus status) => switch (status) {
    AttendanceStatus.notCheckedIn => Icons.schedule_rounded,
    AttendanceStatus.present => Icons.check_circle_rounded,
    AttendanceStatus.late => Icons.running_with_errors_rounded,
    AttendanceStatus.halfDay => Icons.timelapse_rounded,
    AttendanceStatus.leave => Icons.beach_access_rounded,
    AttendanceStatus.absent => Icons.person_off_outlined,
    AttendanceStatus.checkedOut => Icons.logout_rounded,
  };
}

/// Circular initials avatar used in staff lists and headers.
class StaffAvatar extends StatelessWidget {
  const StaffAvatar({
    super.key,
    required this.initials,
    this.size = 44,
    this.background,
    this.foreground,
  });

  final String initials;
  final double size;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background ?? AppColors.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: foreground ?? AppColors.primaryDark,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Small labelled figure used across the summary cards (spec §17, §18).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? AppColors.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: tint),
            const SizedBox(height: 6),
          ],
          Text(
            value,
            style: TextStyle(
              color: tint,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
