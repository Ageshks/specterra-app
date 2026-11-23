import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/staff_widgets.dart';
import 'transfer_decision_bar.dart';

/// "Transfer History" (spec §8).
///
/// Lets an employee review every transfer request they raised, with the
/// outcome, so nothing silently disappears from their record.
class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({
    super.key,
    this.managerView = false,
    this.requests,
  });

  /// Manager variant: shows requests awaiting a decision, with actions.
  final bool managerView;

  /// Lets the manager screen pass its own queue in.
  final List<TransferRequest>? requests;

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final records =
        requests ?? (managerView ? data.pendingTransfers : data.myTransfers);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(managerView ? 'Transfer Requests' : 'Transfer History'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: records.isEmpty
          ? EmptyState(
              icon: Icons.swap_horiz_rounded,
              title: managerView ? 'Nothing to review' : 'No transfers yet',
              message: managerView
                  ? 'There are no transfer requests waiting for approval.'
                  : 'Transfer requests you raise will be listed here with '
                        'their outcome.',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                24,
              ),
              itemCount: records.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TransferHistoryCard(
                  request: records[index],
                  showApprovals: managerView,
                ),
              ),
            ),
    );
  }
}

/// §8 — work ID, customer, original employee, transferred to, reason, date,
/// status.
class TransferHistoryCard extends StatelessWidget {
  const TransferHistoryCard({
    super.key,
    required this.request,
    this.showApprovals = false,
  });

  final TransferRequest request;
  final bool showApprovals;

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
                  request.workId,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              StatusBadge.transfer(request.status, dense: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            request.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            request.serviceType,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          TransferPair(
            label: 'Original Employee',
            value: request.originalEmployeeName,
          ),
          TransferPair(
            label: 'Transferred To',
            value: request.requestedStaffName,
          ),
          TransferPair(
            label: 'Date',
            value: Formatters.dayMonthYear(request.requestedAt),
          ),
          const SizedBox(height: 9),
          Text(
            request.reason,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          if (request.managerNote.isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Manager: ${request.managerNote}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  height: 1.4,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
          if (showApprovals) ...[
            const SizedBox(height: 13),
            TransferDecisionBar(request: request),
          ],
        ],
      ),
    );
  }
}

/// Label / value pair inside a transfer card.
class TransferPair extends StatelessWidget {
  const TransferPair({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 138,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
