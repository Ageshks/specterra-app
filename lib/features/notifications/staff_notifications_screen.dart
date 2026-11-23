import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/feedback_views.dart';
import '../leave/leave_application_screen.dart';
import '../manager/manager_transfers_screen.dart';
import '../billing/billing_screens.dart';
import '../attendance/overtime_history_screen.dart';
import '../jobs/service_report_create_screen.dart';
import '../../core/network/api_client.dart';

class StaffNotificationsScreen extends StatefulWidget {
  const StaffNotificationsScreen({super.key});

  @override
  State<StaffNotificationsScreen> createState() =>
      _StaffNotificationsScreenState();
}

class _StaffNotificationsScreenState extends State<StaffNotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<StaffNotification> _notifications = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notifications = await AppScope.read(
        context,
      ).repository.fetchNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(StaffNotification notification) async {
    final repository = AppScope.read(context).repository;
    final messenger = ScaffoldMessenger.of(context);
    if (!notification.isRead) {
      try {
        await repository.markNotificationRead(notification.id);
        if (mounted) {
          setState(() {
            _notifications = _notifications
                .map(
                  (item) => item.id == notification.id
                      ? StaffNotification(
                          id: item.id,
                          title: item.title,
                          message: item.message,
                          time: item.time,
                          isRead: true,
                          type: item.type,
                          referenceType: item.referenceType,
                          referenceId: item.referenceId,
                        )
                      : item,
                )
                .toList();
          });
        }
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
    if (!mounted) return;
    if (notification.type.toUpperCase() == 'ATTENDANCE_AUTO_CHECKOUT') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const OvertimeHistoryScreen(showAutoCheckoutNotice: true),
        ),
      );
    } else if (notification.type.toUpperCase() == 'OVERTIME_REMINDER' ||
        notification.referenceType?.toLowerCase() == 'overtime_reminder') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const OvertimeHistoryScreen()),
      );
    } else if (notification.referenceType?.toLowerCase() == 'leave' ||
        notification.type.toUpperCase() == 'LEAVE_DECISION') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => repository.isManager
              ? const ManagerTransfersScreen()
              : const LeaveApplicationScreen(),
        ),
      );
    } else if (notification.type.toUpperCase() ==
            'REPORT_CORRECTION_REQUESTED' &&
        notification.referenceId?.isNotEmpty == true) {
      final controller = AppScope.read(context);
      WorkJob? jobForReport() {
        for (final job in controller.data.jobs) {
          if (job.report?.id == notification.referenceId) return job;
        }
        return null;
      }

      var job = jobForReport();
      if (job == null) {
        await controller.refresh();
        if (!mounted) return;
        job = jobForReport();
      }
      if (job != null) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ServiceReportCreateScreen(job: job!),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Could not find this work report. Refresh your work list and try again.',
            ),
          ),
        );
      }
    } else if (notification.referenceType?.toLowerCase() == 'service_invoice' &&
        notification.referenceId?.isNotEmpty == true) {
      try {
        final invoice = await repository.fetchBilling(
          notification.referenceId!,
        );
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BillingDetailsScreen(invoice: invoice),
          ),
        );
      } on ApiException catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.message)));
        }
      }
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(notification.title),
          content: Text(notification.message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = AppScope.of(context).repository;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_notifications.any((item) => !item.isRead))
            TextButton(
              onPressed: () async {
                try {
                  await repository.markAllNotificationsRead();
                  if (mounted) {
                    setState(
                      () => _notifications = _notifications
                          .map(
                            (item) => StaffNotification(
                              id: item.id,
                              title: item.title,
                              message: item.message,
                              time: item.time,
                              isRead: true,
                              type: item.type,
                              referenceType: item.referenceType,
                              referenceId: item.referenceId,
                            ),
                          )
                          .toList(),
                    );
                  }
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : _notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              message: 'New updates will appear here.',
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppTheme.gutter),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  return Card(
                    color: item.isRead ? AppColors.surface : AppColors.mintSoft,
                    child: ListTile(
                      onTap: () => _open(item),
                      leading: Icon(
                        item.referenceType?.toLowerCase() == 'leave'
                            ? Icons.beach_access_rounded
                            : Icons.notifications_active_outlined,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${item.message}\n${item.time}'),
                      isThreeLine: true,
                      trailing: item.isRead
                          ? null
                          : const Icon(
                              Icons.circle,
                              size: 9,
                              color: AppColors.primary,
                            ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
