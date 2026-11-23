import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/supporting_models.dart';
import '../../state/app_state.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';

/// Free water quality checkups: what is covered and the visit schedule.
class CheckupsScreen extends StatelessWidget {
  const CheckupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Free Checkups')),
      body: _body(context, controller),
    );
  }

  Widget _body(BuildContext context, AppController controller) {
    final data = controller.data;

    if (data.isLoadingData && data.checkups.isEmpty) {
      return const SkeletonList(itemCount: 4, itemHeight: 96);
    }
    if (data.dataError != null && data.checkups.isEmpty) {
      return ErrorState(message: data.dataError!, onRetry: controller.reload);
    }

    final upcoming = data.checkups.where((c) => !c.isCompleted).toList();
    final past = data.checkups.where((c) => c.isCompleted).toList();

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
          const _CoverageCard(),
          const SizedBox(height: 18),
          if (upcoming.isEmpty && past.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.science_outlined,
                title: 'No checkups scheduled',
                message:
                    'Book a free water quality checkup and an engineer '
                    'will visit your home.',
                actionLabel: 'Request checkup',
                onAction: () => _requestCheckup(context),
              ),
            ),
          if (upcoming.isNotEmpty) ...[
            const SectionHeader(title: 'Upcoming', padding: EdgeInsets.zero),
            const SizedBox(height: 10),
            ...upcoming.map(
              (checkup) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckupCard(checkup: checkup, isUpcoming: true),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (past.isNotEmpty) ...[
            const SectionHeader(title: 'Completed', padding: EdgeInsets.zero),
            const SizedBox(height: 10),
            ...past.map(
              (checkup) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _CheckupCard(checkup: checkup, isUpcoming: false),
              ),
            ),
          ],
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () => _requestCheckup(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Request a free checkup'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCheckup(BuildContext context) async {
    final controller = CustomerScope.of(context);
    final address = controller.data.addresses.isEmpty
        ? null
        : controller.data.addresses.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request free checkup'),
        content: const Text(
          'A SPECTERRA engineer will collect a water sample and test it for '
          'TDS, hardness, pH and turbidity. Free for AMC members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final appointment = await controller.repository.requestCheckup(
      dateLabel: 'Sat, 21 Mar 2026',
      slotLabel: '10:00 AM – 12:00 PM',
      // No saved addresses yet for a fresh account -> keep the typed text
      // generic instead of inventing a fake street address.
      address: address?.lines ?? 'To be confirmed on call',
    );
    await controller.reload();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Checkup booked for ${appointment.dateLabel}, '
          '${appointment.slotLabel}',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    const items = <(IconData, String, String)>[
      (Icons.water_drop_outlined, 'TDS', 'Total dissolved solids'),
      (Icons.opacity_outlined, 'Hardness', 'Calcium & magnesium'),
      (Icons.science_outlined, 'pH Level', 'Acidity balance'),
      (Icons.blur_on_rounded, 'Turbidity', 'Clarity of water'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.tileGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('What we test', style: textTheme.titleMedium),
              ),
              const StatusPill(
                label: 'Free',
                color: AppColors.primary,
                background: Colors.white,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(item.$1, size: 17, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Text(
                    item.$2,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('— ${item.$3}', style: textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckupCard extends StatelessWidget {
  const _CheckupCard({required this.checkup, required this.isUpcoming});

  final CheckupAppointment checkup;
  final bool isUpcoming;

  @override
  Widget build(BuildContext context) {
    final tint = isUpcoming ? AppColors.primary : AppColors.muted;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.science_outlined,
                size: 44,
                iconSize: 22,
                background: AppColors.mintSoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkup.dateLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkup.slotLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: isUpcoming ? 'Scheduled' : 'Completed',
                color: tint,
                background: AppColors.mintSoft,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          InfoRow(
            icon: Icons.person_outline_rounded,
            text: checkup.engineerName,
          ),
          InfoRow(
            icon: Icons.location_on_outlined,
            text: checkup.address,
            maxLines: 2,
          ),
          if (checkup.sampleId != null)
            InfoRow(
              icon: Icons.qr_code_2_rounded,
              text: 'Sample ${checkup.sampleId}',
            ),
        ],
      ),
    );
  }
}
