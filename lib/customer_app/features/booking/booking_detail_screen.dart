import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../tracking/tracking_screen.dart';

/// Full detail of one booking with status, technician and price summary.
class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

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
        appBar: AppBar(title: const Text('Booking')),
        body: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'Booking not found',
          message: 'This booking may have been removed.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final resolved = booking;
    final textTheme = Theme.of(context).textTheme;
    final technician = resolved.technician;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        actions: [
          IconButton(
            tooltip: 'Track',
            icon: const Icon(Icons.my_location_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TrackingScreen(bookingId: resolved.id),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          32,
        ),
        children: [
          _StatusHero(booking: resolved),
          const SizedBox(height: 18),
          if (technician != null) ...[
            _TechnicianCard(technician: technician),
            const SizedBox(height: 14),
          ],
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appointment', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                DetailRow(
                  icon: Icons.water_drop_outlined,
                  label: 'Service',
                  value: resolved.serviceName,
                ),
                DetailRow(
                  icon: Icons.event_rounded,
                  label: 'Date',
                  value: Formatters.longDate(resolved.scheduledAt),
                ),
                DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Time',
                  value: Formatters.time(resolved.scheduledAt),
                ),
                DetailRow(
                  icon: Icons.location_on_outlined,
                  label: 'Address',
                  value: resolved.address,
                ),
                DetailRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Booking ID',
                  value: resolved.id,
                ),
                if (resolved.notes.isNotEmpty)
                  DetailRow(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Notes',
                    value: resolved.notes,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Price details', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                _AmountRow(
                  label: 'Service charge',
                  value: Formatters.rupees(resolved.amount),
                ),
                const _AmountRow(label: 'Visit & labour', value: 'Included'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
                _AmountRow(
                  label: 'Total payable',
                  value: Formatters.rupees(resolved.amount),
                  emphasise: true,
                ),
                const SizedBox(height: 8),
                const InfoNote(
                  icon: Icons.payments_outlined,
                  message:
                      'Pay by UPI, card or cash after the service is done.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (resolved.status.isActive ||
              resolved.status == BookingStatus.upcoming)
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrackingScreen(bookingId: resolved.id),
                ),
              ),
              icon: const Icon(Icons.near_me_rounded, size: 18),
              label: const Text('Track technician'),
            )
          else if (resolved.status == BookingStatus.completed)
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invoice download coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              ),
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('Download invoice'),
            ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isCancelled = booking.status == BookingStatus.cancelled;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: booking.status.backgroundColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              isCancelled
                  ? Icons.cancel_rounded
                  : booking.status == BookingStatus.completed
                  ? Icons.task_alt_rounded
                  : Icons.water_drop_rounded,
              color: booking.status.foregroundColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.status.label,
                  style: textTheme.titleMedium?.copyWith(
                    color: booking.status.foregroundColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Formatters.dateTime(booking.scheduledAt),
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  Formatters.relativeDay(booking.scheduledAt),
                  style: textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.technician});

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
                  '${technician.role} • ${technician.experienceYears} yrs exp',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${technician.rating} • ${technician.vehicle}',
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
          IconButton(
            tooltip: 'Call technician',
            icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Calling ${technician.phone}'),
                behavior: SnackBarBehavior.floating,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasise = false,
  });

  final String label;
  final String value;
  final bool emphasise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasise
                ? textTheme.titleSmall
                : textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          Text(
            value,
            style: emphasise
                ? textTheme.titleMedium?.copyWith(color: AppColors.primary)
                : textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
