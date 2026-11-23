import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/supporting_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';
import '../reports/report_detail_screen.dart';
import '../tracking/tracking_screen.dart';

/// Notification centre with unread marking and deep links.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _onlyUnread = false;

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;
    final items = _onlyUnread
        ? data.notifications.where((n) => !n.isRead).toList()
        : data.notifications;
    final unread = data.unreadNotificationCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: controller.markAllNotificationsRead,
              child: const Text('Mark all read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _body(context, controller, items),
    );
  }

  Widget _body(
    BuildContext context,
    AppController controller,
    List<AppNotification> items,
  ) {
    final data = controller.data;

    if (data.isLoadingData && data.notifications.isEmpty) {
      return const SkeletonList(itemCount: 5, itemHeight: 92);
    }
    if (data.dataError != null && data.notifications.isEmpty) {
      return ErrorState(message: data.dataError!, onRetry: controller.reload);
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: _onlyUnread
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none_rounded,
        title: _onlyUnread ? 'No unread notifications' : 'No notifications',
        message: _onlyUnread
            ? 'You are all caught up.'
            : 'Updates about your bookings and reports will appear here.',
        actionLabel: _onlyUnread ? 'Show all' : null,
        onAction: _onlyUnread
            ? () => setState(() => _onlyUnread = false)
            : null,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          28,
        ),
        children: [
          FilterPillRow(
            labels: const ['All', 'Unread'],
            selectedIndex: _onlyUnread ? 1 : 0,
            onSelected: (index) => setState(() => _onlyUnread = index == 1),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (notification) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _NotificationCard(
                notification: notification,
                onTap: () => _open(context, controller, notification),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(
    BuildContext context,
    AppController controller,
    AppNotification notification,
  ) {
    controller.markNotificationRead(notification.id);
    if (!context.mounted) return;

    switch (notification.id) {
      case 'ntf_1':
        final booking = controller.data.activeBooking;
        if (booking == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TrackingScreen(bookingId: booking.id),
          ),
        );
      case 'ntf_2':
        final report = controller.data.latestReport;
        if (report == null) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ReportDetailScreen(reportId: report.id),
          ),
        );
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUnread = !notification.isRead;

    return AppCard(
      onTap: onTap,
      color: isUnread ? AppColors.mintSoft : AppColors.surface,
      borderColor: isUnread ? AppColors.mint : AppColors.border,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(notification.icon, size: 21, color: notification.tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 5, left: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(notification.message, style: textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      notification.time,
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.hint,
                        fontSize: 11,
                      ),
                    ),
                    if (notification.actionLabel != null) ...[
                      const SizedBox(width: 10),
                      StatusPill(
                        label: notification.actionLabel!,
                        color: notification.tint,
                        background: Colors.white,
                        dense: true,
                      ),
                    ],
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
