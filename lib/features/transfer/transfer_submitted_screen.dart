import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';

/// "Transfer Submitted" confirmation (spec §6).
///
/// Shows the audit trail of the request and, when the policy requires it,
/// makes the manager-approval step explicit.
class TransferSubmittedScreen extends StatelessWidget {
  const TransferSubmittedScreen({super.key, required this.request});

  final TransferRequest request;

  void _backToDashboard(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => _backToDashboard(context),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Back to dashboard',
                ),
              ),
              const _SubmittedHero(),
              const SizedBox(height: 20),
              Text(
                'Transfer Submitted',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                request.requiresManagerApproval
                    ? 'Waiting for Manager Approval'
                    : 'Your manager has been notified of this transfer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: request.requiresManagerApproval
                      ? AppColors.warning
                      : AppColors.info,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(child: SingleChildScrollView(child: _Details(request))),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'RETURN TO DASHBOARD',
                icon: Icons.dashboard_rounded,
                onPressed: () => _backToDashboard(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// §6 — the large confirmation glyph.
class _SubmittedHero extends StatelessWidget {
  const _SubmittedHero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 92,
        height: 92,
        decoration: const BoxDecoration(
          color: AppColors.warningSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.swap_horiz_rounded,
          color: AppColors.warning,
          size: 44,
        ),
      ),
    );
  }
}

/// §6 — Work ID, customer, both employees, reason, date/time and status.
class _Details extends StatelessWidget {
  const _Details(this.request);

  final TransferRequest request;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          DetailRow(
            icon: Icons.tag_rounded,
            label: 'Work ID',
            value: request.workId,
          ),
          DetailRow(
            icon: Icons.person_outline_rounded,
            label: 'Customer',
            value: request.customerName,
          ),
          DetailRow(
            icon: Icons.person_pin_outlined,
            label: 'Original Employee',
            value: request.originalEmployeeName,
          ),
          DetailRow(
            icon: Icons.person_add_alt_rounded,
            label: 'New Employee',
            value: request.requestedStaffName,
          ),
          DetailRow(
            icon: Icons.notes_rounded,
            label: 'Transfer Reason',
            value: request.reason,
          ),
          DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Transfer Date',
            value: Formatters.dayMonthYear(request.requestedAt),
          ),
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Transfer Time',
            value: Formatters.time(request.requestedAt),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 9),
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
    );
  }
}
