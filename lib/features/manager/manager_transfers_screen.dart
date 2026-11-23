import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/models/enums.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../transfer/transfer_decision_bar.dart';
import '../billing/billing_screens.dart';
import '../attendance/overtime_approvals_screen.dart';

/// §7 — manager queue for "Work Transfer Request" notifications.
///
/// Approval queue for supervisors, including transfer and service-report review.
class ManagerTransfersScreen extends StatelessWidget {
  const ManagerTransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final pending = data.pendingTransfers;
    final decided = data.transfers.where((t) => !t.status.isPending).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    final reports = data.jobs
        .where(
          (job) =>
              job.reportReviewStatus == ReportReviewStatus.pendingReview ||
              job.reportReviewStatus == ReportReviewStatus.correctionRequired,
        )
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Work Transfer Request'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Overtime approvals',
            icon: const Icon(Icons.more_time_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const OvertimeApprovalsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Billing history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BillingHistoryScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Billing approvals',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BillingApprovalScreen(),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          14,
          AppTheme.gutter,
          28,
        ),
        children: [
          if (data.manager != null) ManagerStrip(manager: data.manager!),
          const SizedBox(height: 18),
          const _LeaveApprovalQueue(),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Awaiting Your Decision',
            trailing: Text(
              '${pending.length}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (pending.isEmpty)
            const ManagerEmpty(message: 'No requests are waiting.')
          else
            ...pending.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RequestCard(request: request, pending: true),
              ),
            ),
          if (decided.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Decided'),
            ...decided
                .take(5)
                .map(
                  (request) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RequestCard(request: request, pending: false),
                  ),
                ),
          ],
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Service Report Approvals',
            trailing: Text(
              '${reports.length}',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (reports.isEmpty)
            const ManagerEmpty(
              message: 'No service reports are waiting for review.',
            )
          else
            ...reports.map(
              (job) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReportReviewCard(job: job),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportReviewCard extends StatelessWidget {
  const _ReportReviewCard({required this.job});
  final WorkJob job;

  Future<void> _review(
    BuildContext context, {
    required bool approve,
    String note = '',
  }) async {
    final result = await AppScope.read(context).reviewServiceReport(
      workId: job.id,
      approve: approve,
      correctionNote: note,
    );
    if (!context.mounted) return;
    final message =
        result.error ??
        (approve ? 'Report approved.' : 'Correction request sent.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestCorrection(BuildContext context) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request Correction'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Correction note *',
            hintText: 'Explain what needs to be updated.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || note == null) return;
    if (note.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a correction note.')),
      );
      return;
    }
    await _review(context, approve: false, note: note);
  }

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.serviceType,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '${job.id} · ${job.customerName}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(job.serviceReport, maxLines: 5, overflow: TextOverflow.ellipsis),
        if (job.reportReviewStatus ==
            ReportReviewStatus.correctionRequired) ...[
          const SizedBox(height: 8),
          Text(
            'Correction requested: ${job.correctionNote}',
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => _requestCorrection(context),
              child: const Text('Request Correction'),
            ),
            FilledButton(
              onPressed: () => _review(context, approve: true),
              child: const Text('Approve Report'),
            ),
          ],
        ),
      ],
    ),
  );
}

class ManagerStrip extends StatelessWidget {
  const ManagerStrip({super.key, required this.manager});

  final Employee manager;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          StaffAvatar(initials: manager.initials, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manager.name,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${manager.role} - ${manager.employeeId}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// §7 — employee, customer, service, scheduled date, current assignment,
/// requested staff, reason.
class RequestCard extends StatelessWidget {
  const RequestCard({super.key, required this.request, required this.pending});

  final TransferRequest request;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.originalEmployeeName,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              StatusBadge.transfer(request.status, dense: true),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Customer',
                  value: request.customerName,
                ),
              ),
              Expanded(
                child: DetailRow(
                  icon: Icons.water_drop_outlined,
                  label: 'Service',
                  value: request.serviceType,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Scheduled Date',
                  value: Formatters.dayMonthYear(request.scheduledAt),
                ),
              ),
              Expanded(
                child: DetailRow(
                  icon: Icons.schedule_rounded,
                  label: 'Scheduled Time',
                  value: Formatters.time(request.scheduledAt),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DetailRow(
                  icon: Icons.person_pin_outlined,
                  label: 'Current Assignment',
                  value: request.originalEmployeeName,
                ),
              ),
              Expanded(
                child: DetailRow(
                  icon: Icons.person_add_alt_rounded,
                  label: 'Requested Staff',
                  value: request.requestedStaffName,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Transfer Reason',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            request.reason,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (pending) ...[
            const SizedBox(height: 14),
            TransferDecisionBar(request: request),
          ],
        ],
      ),
    );
  }
}

class ManagerEmpty extends StatelessWidget {
  const ManagerEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            const Icon(Icons.inbox_rounded, color: AppColors.hint, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveApprovalQueue extends StatefulWidget {
  const _LeaveApprovalQueue();

  @override
  State<_LeaveApprovalQueue> createState() => _LeaveApprovalQueueState();
}

class _LeaveApprovalQueueState extends State<_LeaveApprovalQueue> {
  bool _loading = true;
  String? _error;
  List<LeaveRequest> _requests = const [];
  bool _busy = false;

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
      final requests = await AppScope.read(context).repository.fetchLeaves();
      if (mounted) {
        setState(() {
          _requests = requests;
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

  Future<void> _decide(LeaveRequest request, bool approve) async {
    setState(() => _busy = true);
    final result = await AppScope.read(
      context,
    ).repository.decideLeave(leaveId: request.id, approve: approve);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result case Failure<LeaveRequest>(:final message)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(approve ? 'Leave approved.' : 'Leave rejected.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _requests
        .where((request) => request.status.toUpperCase() == 'PENDING')
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Leave Requests',
          trailing: Text('${pending.length} pending'),
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          AppCard(
            child: Column(
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          )
        else if (pending.isEmpty)
          const ManagerEmpty(
            message: 'No leave requests are waiting for approval.',
          )
        else
          ...pending.map(
            (request) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    if (request.employeeId.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Employee ID: ${request.employeeId}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '${request.leaveType.replaceAll('_', ' ')} · ${Formatters.fullDate(request.from)} – ${Formatters.fullDate(request.to)}',
                    ),
                    const SizedBox(height: 5),
                    Text(request.reason),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, false),
                            child: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : () => _decide(request, true),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
