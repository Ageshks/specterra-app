import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/feedback_views.dart';

/// Staff leave application form and the signed-in employee’s request history.
class LeaveApplicationScreen extends StatefulWidget {
  const LeaveApplicationScreen({super.key});

  @override
  State<LeaveApplicationScreen> createState() => _LeaveApplicationScreenState();
}

class _LeaveApplicationScreenState extends State<LeaveApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();
  DateTime? _from;
  DateTime? _to;
  String _leaveType = 'ANNUAL';
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<LeaveRequest> _requests = const [];
  bool _didLoadInitially = false;

  StaffRepository get _repository => AppScope.of(context).repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoadInitially) return;
    _didLoadInitially = true;
    _load();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requests = await _repository.fetchLeaves();
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

  Future<void> _pickDate({required bool start}) async {
    final initial = (start ? _from : _to) ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date != null && mounted) {
      setState(() {
        if (start) {
          _from = date;
          if (_to != null && _to!.isBefore(date)) _to = date;
        } else {
          _to = date;
        }
      });
    }
  }

  String _dateLabel(DateTime? date) => date == null
      ? 'Select date'
      : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_from == null || _to == null) {
      setState(() => _error = 'Select the start and end dates for your leave.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await _repository.applyForLeave(
      leaveType: _leaveType,
      from: _from!,
      to: _to!,
      reason: _reason.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result case Failure<LeaveRequest>(:final message)) {
      setState(() => _error = message);
      return;
    }
    _reason.clear();
    setState(() {
      _from = null;
      _to = null;
      _leaveType = 'ANNUAL';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave application submitted.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Apply for Leave'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gutter),
          children: [
            Card(
              color: AppColors.surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                side: const BorderSide(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New leave request',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _leaveType,
                        decoration: const InputDecoration(
                          labelText: 'Leave type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'ANNUAL',
                            child: Text('Annual leave'),
                          ),
                        ],
                        onChanged: _submitting
                            ? null
                            : (value) => setState(
                                () => _leaveType = value ?? 'ANNUAL',
                              ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _pickDate(start: true),
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text('From  ${_dateLabel(_from)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _submitting
                                  ? null
                                  : () => _pickDate(start: false),
                              icon: const Icon(Icons.event_outlined),
                              label: Text('To  ${_dateLabel(_to)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _reason,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Reason',
                          hintText: 'Tell your manager why you need leave',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a reason for your leave.'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _submitting ? 'Submitting…' : 'Submit application',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'My leave requests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_requests.isEmpty)
              const EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leave requests yet',
                message: 'Your submitted leave applications will appear here.',
              )
            else
              ..._requests.map(
                (request) => Card(
                  color: AppColors.surface,
                  elevation: 0,
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.backgroundAlt,
                      child: Icon(
                        Icons.event_note_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      '${_dateLabel(request.from)} – ${_dateLabel(request.to)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${request.leaveType.replaceAll('_', ' ')} · ${request.reason}',
                    ),
                    trailing: Text(
                      request.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: request.status.toUpperCase() == 'APPROVED'
                            ? AppColors.success
                            : request.status.toUpperCase() == 'REJECTED'
                            ? AppColors.danger
                            : AppColors.warning,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
