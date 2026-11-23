import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking.dart';
import '../../state/app_state.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';
import '../booking/booking_detail_screen.dart';
import '../booking/booking_screen.dart';

/// All bookings, split by tab with upcoming and past sections.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key, this.initialTab = 0, this.title = 'My Bookings'});

  final int initialTab;
  final String title;

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late int _tabIndex = widget.initialTab;

  static const List<String> _tabs = <String>[
    'Upcoming',
    'Completed',
    'Cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'New booking',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BookingScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (data.bookings.isNotEmpty)
            FilterPillRow(
              labels: _tabs,
              selectedIndex: _tabIndex,
              onSelected: (index) => setState(() => _tabIndex = index),
            ),
          Expanded(child: _body(context, controller)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, AppController controller) {
    final data = controller.data;

    if (data.isLoadingData && data.bookings.isEmpty) {
      return const SkeletonList(itemCount: 4, itemHeight: 118);
    }
    if (data.dataError != null && data.bookings.isEmpty) {
      return ErrorState(message: data.dataError!, onRetry: controller.reload);
    }

    final bookings = data.bookings.where(_matchesTab).toList();
    if (bookings.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No ${_tabs[_tabIndex].toLowerCase()} bookings',
        message: 'Book a service and it will show up here.',
        actionLabel: 'Book a service',
        onAction: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BookingScreen())),
      );
    }

    bookings.sort((a, b) {
      if (_tabIndex == 0) return a.scheduledAt.compareTo(b.scheduledAt);
      return b.scheduledAt.compareTo(a.scheduledAt);
    });

    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          8,
          AppTheme.gutter,
          28,
        ),
        itemCount: bookings.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return BookingCard(
            booking: booking,
            showActions:
                booking.status != BookingStatus.completed &&
                booking.status != BookingStatus.cancelled,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BookingDetailScreen(bookingId: booking.id),
              ),
            ),
            onTrack: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BookingDetailScreen(bookingId: booking.id),
              ),
            ),
            onCancel: () => _confirmCancel(context, booking),
          );
        },
      ),
    );
  }

  bool _matchesTab(Booking booking) => switch (_tabIndex) {
    0 => booking.isUpcoming || booking.status == BookingStatus.inProgress,
    1 => booking.status == BookingStatus.completed,
    _ => booking.status == BookingStatus.cancelled,
  };

  Future<void> _confirmCancel(BuildContext context, Booking booking) async {
    final controller = CustomerScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text(
          '${booking.serviceName} on ${_dateLabel(booking.scheduledAt)} will be '
          'cancelled. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel booking'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final cancelled = await controller.cancelBooking(booking.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cancelled
              ? 'Booking ${booking.id} cancelled'
              : 'Could not cancel the booking. Please try again.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String _dateLabel(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
