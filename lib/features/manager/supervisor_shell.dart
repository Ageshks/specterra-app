import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/staff_widgets.dart';
import '../unified_home_screen.dart';
import 'manager_transfers_screen.dart';
import '../notifications/staff_notifications_screen.dart';
import '../billing/billing_screens.dart';

/// Manager workspace with one navigation surface for operational sections.
class SupervisorShell extends StatefulWidget {
  const SupervisorShell({super.key});

  @override
  State<SupervisorShell> createState() => _SupervisorShellState();
}

class _SupervisorShellState extends State<SupervisorShell> {
  int _index = 0;
  static const _tabs = <(String, IconData)>[
    ('Dashboard', Icons.dashboard_outlined),
    ('Works', Icons.work_outline_rounded),
    ('Employees', Icons.groups_outlined),
    ('Approvals', Icons.fact_check_outlined),
    ('Profile', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;
    final scheduleJobs = List<WorkJob>.from(data.jobs)
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final pages = <Widget>[
      _ManagerDashboard(
        managerName: data.employee?.name ?? 'Manager',
        totalJobs: data.todayJobs.length,
        activeJobs: data.jobs
            .where((job) => job.status == WorkStatus.inProgress)
            .length,
        completedJobs: data.jobs
            .where((job) => job.status == WorkStatus.completed)
            .length,
        pendingTransfers: data.pendingTransfers.length,
        availableEmployees: data.availableStaff.length,
        todayJobs: data.todayJobs,
        onOpen: (index) => setState(() => _index = index),
      ),
      _ManagerJobsPage(
        title: 'Works & Service Requests',
        jobs: scheduleJobs,
        showAssignment: true,
        staff: data.staff,
      ),
      _EmployeesPage(staff: data.staff),
      const ManagerTransfersScreen(),
      _ManagerProfile(manager: data.employee),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_tabs.length, (i) {
                final selected = _index == i;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _tabs[i].$2,
                          size: 21,
                          color: selected ? AppColors.primary : AppColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tabs[i].$1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerDashboard extends StatelessWidget {
  const _ManagerDashboard({
    required this.managerName,
    required this.totalJobs,
    required this.activeJobs,
    required this.completedJobs,
    required this.pendingTransfers,
    required this.availableEmployees,
    required this.todayJobs,
    required this.onOpen,
  });
  final String managerName;
  final int totalJobs;
  final int activeJobs;
  final int completedJobs;
  final int pendingTransfers;
  final int availableEmployees;
  final List<WorkJob> todayJobs;
  final ValueChanged<int> onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Supervisor Dashboard'),
      actions: [
        IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const StaffNotificationsScreen(),
            ),
          ),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: () => AppScope.read(context).refresh(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: () => AppScope.read(context).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.gutter),
        children: [
          Text(
            'Welcome, $managerName',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            "Here's the team's operational overview for today.",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricTile(
                label: "Today's Requests",
                value: '$totalJobs',
                icon: Icons.inbox_outlined,
              ),
              _MetricTile(
                label: 'Active Jobs',
                value: '$activeJobs',
                icon: Icons.play_circle_outline,
              ),
              _MetricTile(
                label: 'Completed',
                value: '$completedJobs',
                icon: Icons.task_alt_rounded,
              ),
              _MetricTile(
                label: 'Available Staff',
                value: '$availableEmployees',
                icon: Icons.groups_outlined,
              ),
              _MetricTile(
                label: 'Transfer Requests',
                value: '$pendingTransfers',
                icon: Icons.swap_horiz_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            title: "Today's Schedule",
            trailing: Text('${todayJobs.length} jobs'),
          ),
          if (todayJobs.isEmpty)
            const AppCard(child: Text('No jobs are scheduled for today.'))
          else
            ...todayJobs
                .take(4)
                .map(
                  (job) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(
                      onTap: () => onOpen(1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: job.priority.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.water_drop_outlined,
                              color: job.priority.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.serviceType,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${Formatters.time(job.scheduledAt)} · ${job.customerName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _QuickAction(
                label: 'Requests & Works',
                icon: Icons.work_outline,
                onTap: () => onOpen(1),
              ),
              _QuickAction(
                label: 'Assign Work',
                icon: Icons.assignment_ind_outlined,
                onTap: () => onOpen(1),
              ),
              _QuickAction(
                label: 'Schedule',
                icon: Icons.calendar_month_outlined,
                onTap: () => onOpen(1),
              ),
              _QuickAction(
                label: 'Employees',
                icon: Icons.groups_outlined,
                onTap: () => onOpen(2),
              ),
              _QuickAction(
                label: 'Approvals',
                icon: Icons.fact_check_outlined,
                onTap: () => onOpen(3),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - AppTheme.gutter * 2 - 10) / 2,
    child: AppCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleLarge),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - AppTheme.gutter * 2 - 10) / 2,
    child: OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    ),
  );
}

class _ManagerJobsPage extends StatefulWidget {
  const _ManagerJobsPage({
    required this.title,
    required this.jobs,
    this.showAssignment = false,
    this.staff = const [],
  });
  final String title;
  final List<WorkJob> jobs;
  final bool showAssignment;
  final List<StaffMember> staff;

  @override
  State<_ManagerJobsPage> createState() => _ManagerJobsPageState();
}

class _ManagerJobsPageState extends State<_ManagerJobsPage> {
  String _filter = 'All';

  List<WorkJob> get _visibleJobs {
    return widget.jobs
        .where(
          (job) => switch (_filter) {
            'Assigned' => job.status == WorkStatus.assigned,
            'Active' =>
              job.status == WorkStatus.accepted ||
                  job.status == WorkStatus.inProgress,
            'Completed' => job.status == WorkStatus.completed,
            _ => true,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: widget.jobs.isEmpty
        ? const Center(child: Text('No work items to show.'))
        : ListView(
            padding: const EdgeInsets.all(AppTheme.gutter),
            children: [
              if (widget.showAssignment) ...[
                const SectionHeader(title: 'Jobs and current assignments'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Assigned', 'Active', 'Completed']
                        .map(
                          (filter) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_visibleJobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('No jobs match this filter.')),
                ),
              ..._visibleJobs.map((job) {
                StaffMember? assignee;
                for (final person in widget.staff) {
                  if (person.id == job.assignedTo) assignee = person;
                }
                final canAssign =
                    job.status != WorkStatus.completed &&
                    job.status != WorkStatus.inProgress;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.serviceType,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${job.id} · ${job.customerName}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${Formatters.dayMonthYear(job.scheduledAt)} · ${Formatters.time(job.scheduledAt)}',
                        ),
                        Text(
                          'Assigned to: ${assignee?.name ?? job.assignedTo}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                job.status.label,
                                style: TextStyle(
                                  color: job.status.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              'Priority: ${job.priority.label}',
                              style: TextStyle(
                                color: job.priority.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (widget.showAssignment && canAssign) ...[
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => _AssignmentForm(job: job),
                              ),
                              icon: const Icon(
                                Icons.edit_calendar_outlined,
                                size: 18,
                              ),
                              label: const Text('Assign / Schedule'),
                            ),
                          ),
                        ],
                        if (job.isBillable && job.workOrderId.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BillingEditorScreen(job: job),
                                ),
                              ),
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                              label: const Text('Service billing'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
  );
}

class _AssignmentForm extends StatefulWidget {
  const _AssignmentForm({required this.job});
  final WorkJob job;
  @override
  State<_AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends State<_AssignmentForm> {
  late final TextEditingController _instructions = TextEditingController(
    text: widget.job.managerInstructions,
  );
  late final _serviceAmount = TextEditingController(
    text: widget.job.baseServiceAmount > 0
        ? widget.job.baseServiceAmount.toStringAsFixed(2)
        : '',
  );
  final _travelDistance = TextEditingController();
  final _travelRate = TextEditingController();
  final _otherExpenses = TextEditingController();
  String? _staffId;
  late DateTime _scheduledAt = widget.job.scheduledAt;
  late WorkPriority _priority = widget.job.priority;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _instructions.dispose();
    _serviceAmount.dispose();
    _travelDistance.dispose();
    _travelRate.dispose();
    _otherExpenses.dispose();
    super.dispose();
  }

  double _value(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  double get _estimatedTa => _value(_travelDistance) * _value(_travelRate);

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) {
      setState(
        () => _scheduledAt = DateTime(
          selected.year,
          selected.month,
          selected.day,
          _scheduledAt.hour,
          _scheduledAt.minute,
        ),
      );
    }
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (selected != null) {
      setState(
        () => _scheduledAt = DateTime(
          _scheduledAt.year,
          _scheduledAt.month,
          _scheduledAt.day,
          selected.hour,
          selected.minute,
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (_staffId == null) {
      setState(() => _error = 'Select an available employee.');
      return;
    }
    final numericFields = [
      _serviceAmount,
      _travelDistance,
      _travelRate,
      _otherExpenses,
    ];
    if (numericFields.any(
      (field) =>
          field.text.trim().isNotEmpty &&
          (double.tryParse(field.text.trim()) == null ||
              !_value(field).isFinite ||
              _value(field) < 0),
    )) {
      setState(() => _error = 'Enter valid non-negative amounts and distance.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await AppScope.read(context).assignWork(
      workId: widget.job.id,
      staffId: _staffId!,
      scheduledAt: _scheduledAt,
      priority: _priority,
      instructions: _instructions.text,
      estimatedServiceAmount: _value(_serviceAmount),
      travelDistanceKm: _value(_travelDistance),
      travelAllowanceRate: _value(_travelRate),
      estimatedOtherExpenses: _value(_otherExpenses),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result is Failure<WorkJob>) {
      setState(() => _error = result.message);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Work assigned and scheduled.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = AppScope.of(context).data.availableStaff;
    return AlertDialog(
      title: const Text('Assign Work'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.job.location.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Work location: ${widget.job.location}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
            if (widget.job.location.isNotEmpty) const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _staffId,
              decoration: const InputDecoration(
                labelText: 'Available Employee',
              ),
              items: available
                  .map(
                    (person) => DropdownMenuItem(
                      value: person.id,
                      child: Text('${person.name} · ${person.employeeId}'),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _staffId = value;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(Formatters.dayMonthYear(_scheduledAt)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickTime,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(Formatters.time(_scheduledAt)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<WorkPriority>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Priority'),
              items: WorkPriority.values
                  .map(
                    (priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.label),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) setState(() => _priority = value);
                    },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _serviceAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Estimated service amount (₹)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _travelDistance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Travel distance (km)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _travelRate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'TA rate (₹/km)',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Estimated travel allowance: ₹${_estimatedTa.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _otherExpenses,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Other estimated expenses (₹)',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Estimated total: ₹${(_value(_serviceAmount) + _estimatedTa + _value(_otherExpenses)).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instructions,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Instructions'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Assign Work'),
        ),
      ],
    );
  }
}

class _EmployeesPage extends StatelessWidget {
  const _EmployeesPage({required this.staff});
  final List<StaffMember> staff;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Employees'),
      actions: [
        IconButton(
          tooltip: 'Create employee',
          onPressed: () async {
            final created = await showDialog<bool>(
              context: context,
              builder: (_) => const _CreateEmployeeDialog(),
            );
            if (created == true && context.mounted) {
              await AppScope.read(context).refresh();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Employee created.')),
                );
              }
            }
          },
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.gutter),
      children: [
        SectionHeader(title: 'Field team', trailing: Text('${staff.length}')),
        ...staff.map(
          (person) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StaffAvatar(initials: person.initials, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          person.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${person.employeeId} · ${person.role}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            StatusPill(
                              label: person.availability.label,
                              color: person.availability.color,
                              background: person.availability.background,
                              icon: person.availability.icon,
                              dense: true,
                            ),
                            StatusPill(
                              label: '${person.assignedJobs} active jobs',
                              color: AppColors.info,
                              background: AppColors.infoSoft,
                              dense: true,
                            ),
                          ],
                        ),
                        if (person.phone.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            person.phone,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CreateEmployeeDialog extends StatefulWidget {
  const _CreateEmployeeDialog();

  @override
  State<_CreateEmployeeDialog> createState() => _CreateEmployeeDialogState();
}

class _CreateEmployeeDialogState extends State<_CreateEmployeeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _designation = TextEditingController(text: 'Field Technician');
  String _format = 'SGPLEMP';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _designation.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await AppScope.read(context).repository.createEmployee(
      firstName: _firstName.text,
      lastName: _lastName.text,
      email: _email.text,
      phone: _phone.text,
      password: _password.text,
      designation: _designation.text,
      employeeIdFormat: _format,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result case Failure<StaffMember>(:final message)) {
      setState(() => _error = message);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create employee'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Required'
                          : null,
                    ),
                  ),
                ],
              ),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Work email'),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                ),
              ),
              TextFormField(
                controller: _designation,
                decoration: const InputDecoration(labelText: 'Designation'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password (min. 8 characters)',
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _format,
                decoration: const InputDecoration(
                  labelText: 'Employee ID format',
                ),
                items: const [
                  DropdownMenuItem(value: 'SGPLEMP', child: Text('SGPLEMP…')),
                  DropdownMenuItem(
                    value: 'SGPL/NAPS/',
                    child: Text('SGPL/NAPS/…'),
                  ),
                  DropdownMenuItem(value: 'SGPLTEMP', child: Text('SGPLTEMP…')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _format = value ?? 'SGPLEMP'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _create,
        child: _saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Create'),
      ),
    ],
  );
}

class _ManagerProfile extends StatelessWidget {
  const _ManagerProfile({required this.manager});
  final Employee? manager;

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to access the supervisor workspace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await AppScope.read(context).signOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const UnifiedHomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final person = manager;
    return Scaffold(
      appBar: AppBar(title: const Text('Supervisor Profile')),
      body: person == null
          ? const Center(child: Text('Manager profile unavailable.'))
          : ListView(
              padding: const EdgeInsets.all(AppTheme.gutter),
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('${person.role} · ${person.employeeId}'),
                      const SizedBox(height: 12),
                      Text(person.department),
                      Text(person.phone),
                      Text(person.email),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Log Out'),
                ),
              ],
            ),
    );
  }
}
