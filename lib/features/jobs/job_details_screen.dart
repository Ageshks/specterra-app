import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../transfer/transfer_work_screen.dart';
import 'work_execution_screen.dart';
import 'service_report_create_screen.dart';
import '../billing/billing_screens.dart';

/// Work details for the signed-in technician (spec §2).
///
/// The action bar is deliberately asymmetric: START WORK is the filled
/// primary action, TRANSFER WORK is an outlined secondary sitting below the
/// call/location shortcuts, so it cannot be hit by accident.
class JobDetailsScreen extends StatefulWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  Future<void> _accept(BuildContext context, WorkJob job) async {
    final controller = AppScope.read(context);
    final result = await controller.acceptJob(job.id);
    if (!context.mounted) return;

    if (result is Failure<WorkJob>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
    }
  }

  Future<void> _start(BuildContext context, WorkJob job) async {
    // A restored IN_PROGRESS assignment is already started on the backend.
    // Reopen its execution screen instead of calling the accepted-only start
    // endpoint a second time.
    if (job.status == WorkStatus.inProgress) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WorkExecutionScreen(jobId: job.id),
        ),
      );
      return;
    }

    final controller = AppScope.read(context);
    final result = await controller.startJob(job.id);
    if (!context.mounted) return;

    if (result is Failure<WorkJob>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkExecutionScreen(jobId: job.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;

    final matches = data.jobs.where((j) => j.id == widget.jobId);
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Work Details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.gutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.search_off_rounded,
                  size: 40,
                  color: AppColors.hint,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This work order is no longer assigned to you.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 13.5),
                ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'BACK TO MY JOBS',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final job = matches.first;

    // Once a transfer is in flight the only thing left to do is watch it.
    if (job.status.inTransferBranch) {
      return _TransferPendingScaffold(job: job);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Work Details'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                20,
              ),
              children: [
                _TitleBlock(job: job),
                if (job.isBillable && job.workOrderId.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Post-service billing',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Add delivery, transport, material, spare part or other charges for this completed job.',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<bool>(
                                builder: (_) => BillingEditorScreen(job: job),
                              ),
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            label: const Text('Open Service Billing'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (job.reportReviewStatus ==
                    ReportReviewStatus.correctionRequired) ...[
                  const SizedBox(height: 14),
                  InfoCallout(
                    message:
                        'Report correction required: ${job.correctionNote}',
                    icon: Icons.edit_note_rounded,
                    tone: CalloutTone.warning,
                  ),
                ],
                const SizedBox(height: 18),
                const SectionHeader(title: 'Customer & Site'),
                _InfoCard(job: job),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Schedule'),
                _ScheduleCard(job: job),
                const SizedBox(height: 18),
                const SectionHeader(title: 'Manager Instructions'),
                _Instructions(job: job),
              ],
            ),
          ),
          _ActionBar(
            job: job,
            canCreateReport: controller.repository.role == 'EMPLOYEE',
            busy: data.busy,
            onAccept: () => _accept(context, job),
            onStart: () => _start(context, job),
            onCall: () => _callCustomer(job),
            onMap: () => _openLocation(job),
            onTransfer: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => TransferWorkScreen(job: job),
              ),
            ),
            onEditReport: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ServiceReportCreateScreen(job: job),
              ),
            ),
            onCreateReport: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ServiceReportCreateScreen(job: job),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _callCustomer(WorkJob job) async {
    final phone = job.contactNumber.trim();
    if (phone.isEmpty) {
      _snack(context, 'No customer phone number is available.');
      return;
    }
    final dialablePhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (dialablePhone.isEmpty || dialablePhone == '+') {
      _snack(context, 'The customer phone number is invalid.');
      return;
    }
    final dialer = Uri(scheme: 'tel', path: dialablePhone);
    if (!await launchUrl(dialer, mode: LaunchMode.externalApplication)) {
      if (mounted) _snack(context, 'Could not open the phone dialer.');
    }
  }

  Future<void> _openLocation(WorkJob job) async {
    final address = job.location.trim();
    final hasCoordinates = job.latitude != null && job.longitude != null;
    if (address.isEmpty && !hasCoordinates) {
      _snack(context, 'No customer address is available.');
      return;
    }
    final destination = hasCoordinates
        ? '${job.latitude},${job.longitude}'
        : address;
    final map = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': destination,
    });
    if (!await launchUrl(map, mode: LaunchMode.externalApplication) &&
        mounted) {
      _snack(context, 'Could not open a maps app or browser.');
    }
  }
}

/// §1/§2 — customer, company, service, location, contact (§2 header block).
class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              job.workOrderId.isEmpty ? job.id : job.workOrderId,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            const Spacer(),
            StatusBadge.priority(job.priority),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          job.customerName,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          job.companyName,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text(
              'Work status',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge.work(job.status),
          ],
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Customer',
            value: job.customerName,
          ),
          DetailRow(
            icon: Icons.business_outlined,
            label: 'Company',
            value: job.companyName,
          ),
          DetailRow(
            icon: Icons.water_drop_outlined,
            label: 'Service',
            value: job.serviceType,
          ),
          DetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: job.location,
          ),
          if (job.latitude != null && job.longitude != null)
            DetailRow(
              icon: Icons.my_location_outlined,
              label: 'Coordinates',
              value: '${job.latitude}, ${job.longitude}',
            ),
          DetailRow(
            icon: Icons.phone_outlined,
            label: 'Contact Number',
            value: job.contactNumber,
          ),
          if (job.managerName.isNotEmpty)
            DetailRow(
              icon: Icons.supervisor_account_outlined,
              label: 'Manager',
              value: job.managerName,
            ),
          if (job.managerPhone.isNotEmpty)
            DetailRow(
              icon: Icons.phone_outlined,
              label: 'Manager Contact',
              value: job.managerPhone,
            ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Scheduled Date',
            value: Formatters.dayMonthYear(Formatters.inIndia(job.scheduledAt)),
          ),
          if (job.assignedAt != null)
            DetailRow(
              icon: Icons.assignment_turned_in_outlined,
              label: 'Assigned Date',
              value: Formatters.dayMonthYear(
                Formatters.inIndia(job.assignedAt!),
              ),
            ),
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Scheduled Time',
            value: Formatters.time(job.scheduledAt),
          ),
          DetailRow(
            icon: Icons.flag_outlined,
            label: 'Priority',
            value: job.priority.label,
          ),
        ],
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            size: 17,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              job.managerInstructions,
              style: const TextStyle(
                color: AppColors.inkSoft,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// §2 — START WORK (or ACCEPT & VIEW WORK) is primary; CALL CUSTOMER and
/// OPEN LOCATION are shortcuts; TRANSFER WORK is deliberately outlined and
/// placed last so it is never the easy tap.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.job,
    required this.canCreateReport,
    required this.busy,
    required this.onAccept,
    required this.onStart,
    required this.onCall,
    required this.onMap,
    required this.onTransfer,
    required this.onEditReport,
    required this.onCreateReport,
  });

  final WorkJob job;
  final bool canCreateReport;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onStart;
  final VoidCallback onCall;
  final VoidCallback onMap;
  final VoidCallback onTransfer;
  final VoidCallback onEditReport;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        12,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              // §1 — an assignment is acknowledged, never declined.
              label: _hasReport
                  ? switch (job.reportReviewStatus) {
                      ReportReviewStatus.draft => 'EDIT DRAFT REPORT',
                      ReportReviewStatus.correctionRequired =>
                        'EDIT & RESUBMIT REPORT',
                      ReportReviewStatus.approved => 'VIEW APPROVED REPORT',
                      ReportReviewStatus.pendingReview => 'VIEW SERVICE REPORT',
                      ReportReviewStatus.notSubmitted => 'VIEW SERVICE REPORT',
                    }
                  : job.status == WorkStatus.assigned
                  ? 'ACCEPT & VIEW WORK'
                  : job.status == WorkStatus.accepted
                  ? 'START WORK'
                  : job.status == WorkStatus.inProgress
                  ? 'CONTINUE WORK'
                  : (job.status == WorkStatus.completed ||
                            job.status == WorkStatus.awaitingReport) &&
                        canCreateReport
                  ? 'CREATE SERVICE REPORT'
                  : 'COMPLETED',
              icon: _hasReport
                  ? job.reportReviewStatus == ReportReviewStatus.approved
                        ? Icons.fact_check_outlined
                        : Icons.edit_note_rounded
                  : (job.status == WorkStatus.completed ||
                            job.status == WorkStatus.awaitingReport) &&
                        canCreateReport
                  ? Icons.description_outlined
                  : switch (job.status) {
                      WorkStatus.assigned => Icons.task_alt_rounded,
                      WorkStatus.accepted => Icons.play_arrow_rounded,
                      WorkStatus.inProgress => Icons.play_arrow_rounded,
                      _ => Icons.check_rounded,
                    },
              busy: busy,
              onPressed: _hasReport && canCreateReport
                  ? onEditReport
                  : (job.status == WorkStatus.completed ||
                            job.status == WorkStatus.awaitingReport) &&
                        canCreateReport
                  ? onCreateReport
                  : switch (job.status) {
                      WorkStatus.assigned => onAccept,
                      WorkStatus.accepted => onStart,
                      WorkStatus.inProgress => onStart,
                      _ => null,
                    },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'CALL CUSTOMER',
                    icon: Icons.phone_outlined,
                    onPressed: onCall,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    label: 'OPEN LOCATION',
                    icon: Icons.map_outlined,
                    onPressed: onMap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // §2 — secondary weight on purpose; no reject action exists.
            SecondaryButton(
              label: 'TRANSFER WORK',
              icon: Icons.swap_horiz_rounded,
              tint: AppColors.muted,
              onPressed: job.status == WorkStatus.completed ||
                      job.status == WorkStatus.awaitingReport
                  ? null
                  : onTransfer,
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasReport =>
      job.report?.id.isNotEmpty == true ||
      job.reportReviewStatus != ReportReviewStatus.notSubmitted;
}

/// Shown when a transfer request is already out for this work (§6).
class _TransferPendingScaffold extends StatelessWidget {
  const _TransferPendingScaffold({required this.job});

  final WorkJob job;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final request = data.myTransfers
        .where((t) => t.workId == job.id)
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Work Details'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: [
          const InfoCallout(
            message: 'Waiting for Manager Approval',
            icon: Icons.hourglass_top_rounded,
            tone: CalloutTone.warning,
          ),
          const SizedBox(height: 16),
          if (request != null) ...[
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  DetailRow(
                    icon: Icons.person_pin_outlined,
                    label: 'Original Employee',
                    value: request.originalEmployeeName,
                  ),
                  DetailRow(
                    icon: Icons.person_add_alt_rounded,
                    label: 'Requested Staff',
                    value: request.requestedStaffName,
                  ),
                  DetailRow(
                    icon: Icons.notes_rounded,
                    label: 'Transfer Reason',
                    value: request.reason,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        const Text(
                          'Transfer Status',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        StatusBadge.transfer(request.status),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const InfoCallout(
            message:
                'This work stays assigned to you until your manager decides. '
                'You cannot transfer the same work again while it is pending.',
            icon: Icons.info_outline_rounded,
          ),
        ],
      ),
    );
  }
}
