import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/action_widgets.dart';
import '../../widgets/common_widgets.dart';
import 'transfer_submitted_screen.dart';
import 'transfer_widgets.dart';

/// "Transfer Work" screen (spec §3, §4).
///
/// An employee can never decline work, so this is the only escape hatch from
/// an assignment. It enforces the three-step contract: pick an available
/// colleague, give a mandatory reason, confirm.
class TransferWorkScreen extends StatefulWidget {
  const TransferWorkScreen({super.key, required this.job});

  final WorkJob job;

  @override
  State<TransferWorkScreen> createState() => _TransferWorkScreenState();
}

class _TransferWorkScreenState extends State<TransferWorkScreen> {
  final _reasonController = TextEditingController();
  final _reasonFocus = FocusNode();
  String? _selectedStaffId;
  String? _selectedReason;
  bool _showReasonError = false;
  String? _formError;

  static const List<String> _reasonSuggestions = <String>[
    'Already assigned to another job',
    'Technical expertise unavailable',
    'Unable to reach location',
    'Emergency',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  /// Both the staff selection and the note are required before submitting.
  bool get _canSubmit =>
      _selectedStaffId != null &&
      _selectedReason != null &&
      _reasonController.text.trim().isNotEmpty;

  void _onNoteChanged(String _) {
    setState(() {
      if (_showReasonError && _reasonController.text.trim().isNotEmpty) {
        _showReasonError = false;
      }
      _formError = null;
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(() {
        _showReasonError = true;
        _formError = _selectedStaffId == null
            ? 'Select an available staff member to transfer this work.'
            : _selectedReason == null
            ? 'Select a reason for transferring this work.'
            : null;
      });
      return;
    }

    // §5 — confirm before anything is written.
    final confirmed = await _confirmDialog(context);
    if (confirmed != true || !mounted) return;

    final controller = AppScope.read(context);
    final result = await controller.requestTransfer(
      workId: widget.job.id,
      requestedStaffId: _selectedStaffId!,
      reason: '$_selectedReason — ${_reasonController.text.trim()}',
    );
    if (!mounted) return;

    if (result is Failure<TransferRequest>) {
      setState(() => _formError = result.error);
      return;
    }

    final request = (result as Success<TransferRequest>).value;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => TransferSubmittedScreen(request: request),
      ),
    );
  }

  /// §5 — "Confirm Work Transfer?" recap of work, current staff, new staff
  /// and the reason.
  Future<bool?> _confirmDialog(BuildContext context) {
    final staff = AppScope.of(context).data.staff.firstWhere(
      (s) => s.id == _selectedStaffId,
      orElse: () => const StaffMember(
        id: '',
        employeeId: '',
        name: '',
        role: '',
        department: '',
        availability: StaffAvailability.offline,
        assignedJobs: 0,
      ),
    );
    final employee = AppScope.of(context).data.employee;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          title: const Text(
            'Confirm Work Transfer?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Work',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.job.serviceType,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TransferDialogRow(
                  label: 'Current Staff',
                  value: employee?.name ?? '-',
                ),
                TransferDialogRow(label: 'New Staff', value: staff.name),
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
                const SizedBox(height: 3),
                Text(
                  '$_selectedReason — ${_reasonController.text.trim()}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
              child: const Text('CONFIRM TRANSFER'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;
    final busy = data.busy;
    final available = data.availableStaff;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transfer Work'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          12,
          AppTheme.gutter,
          28,
        ),
        children: [
          const Text(
            'If you are unable to complete this assignment, transfer it to '
            'an available staff member.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const SectionHeader(title: 'Work Information'),
          WorkSummaryCard(job: widget.job, currentStaff: data.employee?.name),
          const SizedBox(height: 22),
          SectionHeader(
            title: 'Select Available Staff',
            trailing: Text(
              '${available.length} available',
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (available.isEmpty)
            data.staffError != null
                ? InfoCallout(
                    message:
                        'Could not load transfer recipients: '
                        '${data.staffError}',
                    icon: Icons.error_outline_rounded,
                    tone: CalloutTone.danger,
                  )
                : const NoStaffAvailableCard()
          else
            ...data.staff.map(
              (staff) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: StaffChoiceCard(
                  staff: staff,
                  selected: staff.id == _selectedStaffId,
                  // §3 — only Available staff may be chosen.
                  onTap: staff.isSelectable
                      ? () => setState(() {
                          _selectedStaffId = staff.id;
                          _formError = null;
                        })
                      : null,
                ),
              ),
            ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Transfer Reason *',
              prefixIcon: Icon(Icons.help_outline_rounded),
            ),
            items: _reasonSuggestions
                .map(
                  (reason) =>
                      DropdownMenuItem(value: reason, child: Text(reason)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _selectedReason = value;
              _formError = null;
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            focusNode: _reasonFocus,
            onChanged: _onNoteChanged,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Transfer Note *',
              hintText: 'Add details for your supervisor',
              errorText:
                  _showReasonError && _reasonController.text.trim().isEmpty
                  ? 'Enter a transfer note'
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
            ),
          ),
          if (_formError != null) ...[
            const SizedBox(height: 14),
            InfoCallout(
              message: _formError!,
              icon: Icons.error_outline_rounded,
              tone: CalloutTone.danger,
            ),
          ],
          const SizedBox(height: 18),
          // §6 — be explicit that the manager is involved.
          InfoCallout(
            message: AttendancePolicy.transfersRequireManagerApproval
                ? 'This request will be sent to your manager for approval. '
                      'The work stays assigned to you until they decide.'
                : 'Your manager will be notified of this transfer.',
            icon: Icons.hourglass_top_rounded,
            tone: CalloutTone.warning,
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'TRANSFER WORK',
            icon: Icons.swap_horiz_rounded,
            busy: busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
