import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/staff_repository.dart';
import '../../data/models/models.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';

/// Compact recap of the work being transferred (spec §3).
class WorkSummaryCard extends StatelessWidget {
  const WorkSummaryCard({super.key, required this.job, this.currentStaff});

  final WorkJob job;
  final String? currentStaff;

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
            icon: Icons.water_drop_outlined,
            label: 'Service',
            value: job.serviceType,
          ),
          DetailRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: Formatters.dayMonthYear(job.scheduledAt),
          ),
          DetailRow(
            icon: Icons.schedule_rounded,
            label: 'Time',
            value: Formatters.time(job.scheduledAt),
          ),
          DetailRow(
            icon: Icons.place_outlined,
            label: 'Location',
            value: job.location,
          ),
          DetailRow(
            icon: Icons.badge_outlined,
            label: 'Current Assigned Employee',
            value: currentStaff ?? '-',
          ),
        ],
      ),
    );
  }
}

/// §3 — staff card showing name, ID, department, availability and load.
///
/// Unavailable staff render disabled so the rule is visible rather than only
/// enforced on tap.
class StaffChoiceCard extends StatelessWidget {
  const StaffChoiceCard({
    super.key,
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  final StaffMember staff;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final borderColor = selected
        ? AppColors.primary
        : (enabled ? AppColors.border : AppColors.backgroundAlt);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: selected ? AppColors.mintSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                StaffAvatar(
                  initials: staff.initials,
                  size: 40,
                  background: enabled ? null : AppColors.backgroundAlt,
                  foreground: enabled ? null : AppColors.hint,
                ),
                const SizedBox(width: 11),
                Expanded(child: _StaffDetails(staff: staff)),
                const SizedBox(width: 6),
                if (!enabled)
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 16,
                    color: AppColors.hint,
                  )
                else
                  Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 21,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffDetails extends StatelessWidget {
  const _StaffDetails({required this.staff});

  final StaffMember staff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          staff.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${staff.employeeId} - ${staff.department}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge.availability(staff.availability, dense: true),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.backgroundAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${staff.assignedJobs} job${staff.assignedJobs == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// §3 — empty state when nobody on the team is free.
class NoStaffAvailableCard extends StatelessWidget {
  const NoStaffAvailableCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(Icons.groups_rounded, color: AppColors.hint, size: 30),
            SizedBox(height: 10),
            Text(
              'No staff members are available',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Every technician is busy, on leave or offline. Contact your '
              'manager to reassign this work.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label / value row used inside the confirm-transfer dialog (§5).
class TransferDialogRow extends StatelessWidget {
  const TransferDialogRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
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

/// §4 — mandatory reason textarea with the spec's placeholder and examples.
class TransferReasonField extends StatelessWidget {
  const TransferReasonField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.showError,
    required this.suggestions,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showError;
  final List<String> suggestions;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Reason for Transfer *'),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          minLines: 4,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: 'Please provide the reason for transferring this work...',
            alignLabelWithHint: true,
            // §4 — the transfer is blocked until a reason is supplied.
            errorText: showError ? transferReasonRequired : null,
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Example reasons',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final suggestion in suggestions)
              ActionChip(
                label: Text(
                  suggestion,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: AppColors.backgroundAlt,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                onPressed: () {
                  controller.text = suggestion;
                  onChanged(suggestion);
                },
              ),
          ],
        ),
      ],
    );
  }
}
