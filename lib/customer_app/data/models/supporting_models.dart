import 'package:flutter/material.dart';

/// In-app notification shown on the home banner and notifications tab.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.icon,
    required this.tint,
    this.isRead = false,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String message;
  final String time;
  final IconData icon;
  final Color tint;
  final bool isRead;
  final String? actionLabel;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    message: message,
    time: time,
    icon: icon,
    tint: tint,
    isRead: isRead ?? this.isRead,
    actionLabel: actionLabel,
  );

  /// Parses the live `GET /notifications` payload with safe fallbacks.
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return fallback;
    }

    final rawDate = pick(['createdAt', 'created_at', 'date', 'time']);
    var time = pick(['time', 'timeAgo']);
    if (time.isEmpty && rawDate.isNotEmpty) {
      final parsed = DateTime.tryParse(rawDate);
      time = parsed == null ? rawDate : '${parsed.day}/${parsed.month}/${parsed.year}';
    }
    if (time.isEmpty) time = 'Recently';
    final rawRead = json['isRead'] ?? json['is_read'] ?? json['read'];
    return AppNotification(
      id: pick(['id', '_id', 'notificationId']),
      title: pick(['title', 'subject'], 'Notification'),
      message: pick(['message', 'body', 'description']),
      time: time,
      icon: Icons.notifications_outlined,
      tint: const Color(0xFF1B6FC4),
      isRead: rawRead == true,
      actionLabel: pick(['actionLabel', 'action']),
    );
  }
}

/// A scheduled water-quality checkup visit.
@immutable
class CheckupAppointment {
  const CheckupAppointment({
    required this.id,
    required this.dateLabel,
    required this.slotLabel,
    required this.engineerName,
    required this.address,
    required this.isCompleted,
    this.sampleId,
  });

  final String id;
  final String dateLabel;
  final String slotLabel;
  final String engineerName;
  final String address;
  final bool isCompleted;
  final String? sampleId;
}

/// Water-quality parameters surfaced in the monthly report.
@immutable
class WaterMetric {
  const WaterMetric({
    required this.label,
    required this.value,
    required this.unit,
    required this.percentage,
    required this.isHealthy,
  });

  final String label;
  final String value;
  final String unit;
  final double percentage;
  final bool isHealthy;
}

/// Monthly water treatment report.
@immutable
class WaterReport {
  const WaterReport({
    required this.id,
    required this.title,
    required this.period,
    required this.issuedDate,
    required this.healthScore,
    required this.metrics,
    required this.summary,
    required this.fileSizeMb,
  });

  final String id;
  final String title;
  final String period;
  final String issuedDate;
  final int healthScore;
  final List<WaterMetric> metrics;
  final String summary;
  final double fileSizeMb;
}
