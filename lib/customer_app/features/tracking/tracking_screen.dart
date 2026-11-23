import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

/// Live technician tracking with a schematic route map and status timeline.
class TrackingScreen extends StatelessWidget {
  const TrackingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    Booking? booking;
    for (final candidate in data.bookings) {
      if (candidate.id == bookingId) booking = candidate;
    }

    if (booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Track Service')),
        body: EmptyState(
          icon: Icons.location_off_rounded,
          title: 'Nothing to track',
          message: 'We could not find this booking.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final resolved = booking;
    final technician = resolved.technician;
    final isLive = resolved.status.isActive;
    final progress = _progressFor(resolved.status);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Service'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(38),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              0,
              AppTheme.gutter,
              12,
            ),
            child: Row(
              children: [
                Flexible(
                  child: StatusPill(
                    label: isLive ? 'Live tracking' : resolved.status.label,
                    color: isLive
                        ? AppColors.primary
                        : resolved.status.foregroundColor,
                    background: isLive
                        ? AppColors.mintSoft
                        : resolved.status.backgroundColor,
                    icon: isLive ? Icons.wifi_tethering_rounded : null,
                    dense: true,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    Formatters.relativeDay(resolved.scheduledAt),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          14,
          AppTheme.gutter,
          32,
        ),
        children: [
          _RouteMap(progress: progress, isLive: isLive),
          const SizedBox(height: 16),
          if (technician != null) _TechnicianStrip(technician: technician),
          const SizedBox(height: 16),
          Text(
            'Service progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _Timeline(steps: resolved.trackingSteps),
          if (resolved.notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            InfoNote(
              icon: Icons.sticky_note_2_outlined,
              title: 'Note for the technician',
              message: resolved.notes,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        technician == null
                            ? 'No technician assigned yet'
                            : 'Calling ${technician.phone}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  icon: const Icon(Icons.call_rounded, size: 18),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Chat opened — an agent will reply shortly',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Fraction of the journey completed, in the range 0..1.
  static double _progressFor(BookingStatus status) => switch (status) {
    BookingStatus.upcoming => 0.0,
    BookingStatus.assigned => 0.12,
    BookingStatus.enRoute => 0.55,
    BookingStatus.inProgress => 0.85,
    BookingStatus.completed => 1.0,
    BookingStatus.cancelled => 0.0,
  };
}

/// Schematic route map drawn with a painter — no map SDK dependency.
class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.progress, required this.isLive});

  final double progress;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.mint),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RoutePainter(progress: progress, isLive: isLive),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: StatusPill(
              label: isLive ? 'Technician en route' : 'Route preview',
              color: AppColors.primary,
              background: Colors.white,
              icon: Icons.directions_car_filled_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.progress, required this.isLive});

  final double progress;
  final bool isLive;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final grid = Paint()
      ..color = AppColors.mint.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;

    for (var i = 1; i < 5; i++) {
      final y = size.height * (i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 4; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }

    final start = Offset(size.width * 0.16, size.height * 0.74);
    final end = Offset(size.width * 0.82, size.height * 0.28);
    final controlA = Offset(size.width * 0.34, size.height * 0.30);
    final controlB = Offset(size.width * 0.58, size.height * 0.86);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        controlA.dx,
        controlA.dy,
        controlB.dx,
        controlB.dy,
        end.dx,
        end.dy,
      );

    canvas.drawPath(path, road);

    final travelled = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      pathMetricSlice(path, (progress.clamp(0.0, 1.0)) * pathLength(path)),
      travelled,
    );

    canvas.drawCircle(start, 9, Paint()..color = Colors.white);
    canvas.drawCircle(start, 6, Paint()..color = AppColors.primary);
    _pin(canvas, end, AppColors.danger);

    final current = _pointAt(path, pathLength(path) * progress.clamp(0.0, 1.0));
    if (isLive) {
      canvas.drawCircle(
        current,
        18,
        Paint()
          ..color = AppColors.primary.withValues(alpha: 0.18)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(current, 10, Paint()..color = AppColors.primary);
      canvas.drawCircle(current, 4, Paint()..color = Colors.white);
    } else {
      _pin(canvas, current, AppColors.primary);
    }
  }

  void _pin(Canvas canvas, Offset center, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy + 12)
        ..lineTo(center.dx - 9, center.dy - 3)
        ..lineTo(center.dx + 9, center.dy - 3)
        ..close(),
      Paint()..color = color,
    );
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(center, 6, Paint()..color = color);
  }

  Path pathMetricSlice(Path source, double length) {
    final metric = source.computeMetrics().first;
    return metric.extractPath(0, math.max(0, length));
  }

  double pathLength(Path source) => source.computeMetrics().first.length;

  Offset _pointAt(Path source, double length) {
    final metric = source.computeMetrics().first;
    final tangent = metric.getTangentForOffset(math.min(length, metric.length));
    return tangent?.position ?? Offset.zero;
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isLive != isLive;
}

class _TechnicianStrip extends StatelessWidget {
  const _TechnicianStrip({required this.technician});

  final Technician technician;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary,
            child: Text(
              technician.initials,
              style: textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(technician.name, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${technician.role} • ${technician.vehicle}',
                  style: textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      technician.rating.toStringAsFixed(1),
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${technician.experienceYears} yrs experience',
                        style: textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.steps});

  final List<TrackingStep> steps;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (steps.isEmpty) {
      return const InfoNote(
        icon: Icons.hourglass_empty_rounded,
        message: 'Tracking updates appear once the technician is assigned.',
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: List<Widget>.generate(steps.length, (index) {
          final step = steps[index];
          final isLast = index == steps.length - 1;
          final nodeColor = step.isDone
              ? AppColors.primary
              : step.isCurrent
              ? AppColors.warning
              : AppColors.border;
          final textColor = step.isDone || step.isCurrent
              ? AppColors.text
              : AppColors.muted;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 14),
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: step.isDone || step.isCurrent
                            ? nodeColor
                            : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: nodeColor, width: 2),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: step.isDone
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 14 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          step.title,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: step.isCurrent
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          step.note ?? step.timestamp,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
