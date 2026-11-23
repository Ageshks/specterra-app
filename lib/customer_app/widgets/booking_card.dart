import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models/booking.dart';
import 'common_widgets.dart';
import 'filter_widgets.dart';

/// Summary card for a booking, reused on Home, Bookings and tracking.
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onTrack,
    this.onCancel,
    this.showActions = true,
  });

  final Booking booking;
  final VoidCallback? onTap;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canCancel = booking.status == BookingStatus.upcoming;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile(icon: booking.serviceIcon, size: 46, iconSize: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceName,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${booking.id}',
                      style: textTheme.bodySmall?.copyWith(letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: booking.status.label,
                color: booking.status.foregroundColor,
                background: booking.status.backgroundColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          InfoRow(
            icon: Icons.event_outlined,
            text:
                '${Formatters.longDate(booking.scheduledAt)}  •  '
                '${Formatters.time(booking.scheduledAt)}',
          ),
          const SizedBox(height: 8),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: booking.address,
            maxLines: 2,
          ),
          const SizedBox(height: 8),
          InfoRow(
            icon: Icons.payments_outlined,
            text: Formatters.rupees(booking.amount),
            bold: true,
          ),
          if (showActions && (onTrack != null || onCancel != null)) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                if (onTrack != null &&
                    booking.status != BookingStatus.cancelled)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: FilledButton(
                        onPressed: onTrack,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                        ),
                        child: const Text('Track'),
                      ),
                    ),
                  ),
                if (onTrack != null && onCancel != null)
                  const SizedBox(width: 10),
                if (onCancel != null && canCancel)
                  Expanded(
                    child: SizedBox(
                      height: 42,
                      child: OutlinedButton(
                        onPressed: onCancel,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.dangerSoft),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon plus text line used in cards and detail summaries.
class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.text,
    this.maxLines = 1,
    this.bold = false,
    this.iconColor,
  });

  final IconData icon;
  final String text;
  final int maxLines;
  final bool bold;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: iconColor ?? AppColors.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: bold
                ? textTheme.titleSmall?.copyWith(color: AppColors.primary)
                : textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
          ),
        ),
      ],
    );
  }
}
