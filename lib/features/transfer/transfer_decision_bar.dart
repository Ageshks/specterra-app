import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';

/// §7 — APPROVE TRANSFER / KEEP CURRENT ASSIGNMENT.
///
/// The manager can read the employee's reason before deciding, which is the
/// point of the approval step; it is rendered above the buttons rather than
/// hidden behind a tap.
class TransferDecisionBar extends StatelessWidget {
  const TransferDecisionBar({super.key, required this.request});

  final TransferRequest request;

  Future<void> _approve(BuildContext context) async {
    final result = await AppScope.read(context).approveTransfer(request.id);
    if (!context.mounted) return;
    _report(context, result);
  }

  Future<void> _keep(BuildContext context) async {
    final result = await AppScope.read(context).keepAssignment(request.id);
    if (!context.mounted) return;
    _report(context, result);
  }

  void _report(BuildContext context, Result<TransferRequest> result) {
    final messenger = ScaffoldMessenger.of(context);
    if (result is Failure<TransferRequest>) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    final updated = (result as Success<TransferRequest>).value;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          updated.status == TransferStatus.transferred
              ? 'Transfer approved. ${updated.requestedStaffName} now owns '
                    '${updated.workId}.'
              : 'Original assignment kept for ${updated.workId}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = AppScope.of(context).data.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 15,
              color: AppColors.muted,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Review the reason above before deciding.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        PrimaryButton(
          label: 'APPROVE TRANSFER',
          icon: Icons.thumb_up_alt_outlined,
          busy: busy,
          onPressed: () => _approve(context),
        ),
        const SizedBox(height: 9),
        SecondaryButton(
          label: 'KEEP CURRENT ASSIGNMENT',
          icon: Icons.person_pin_outlined,
          onPressed: busy ? null : () => _keep(context),
        ),
      ],
    );
  }
}
