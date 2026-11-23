import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../data/staff_repository.dart';
import '../../state/app_controller.dart';
import '../../widgets/feedback_views.dart';

class ExpenseClaimsScreen extends StatefulWidget {
  const ExpenseClaimsScreen({super.key});

  @override
  State<ExpenseClaimsScreen> createState() => _ExpenseClaimsScreenState();
}

class _ExpenseClaimsScreenState extends State<ExpenseClaimsScreen> {
  static const _categories = <String>[
    'Travel Allowance (TA)',
    'Food',
    'Local Transport',
    'Lodging',
    'Other',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _receiptUrl = TextEditingController();
  DateTime _date = DateTime.now();
  String _category = _categories.first;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<ExpenseClaim> _claims = const [];
  bool _didLoad = false;

  StaffRepository get _repository => AppScope.of(context).repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didLoad) return;
    _didLoad = true;
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _receiptUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final claims = await _repository.fetchExpenses();
      if (mounted) {
        setState(() {
          _claims = claims;
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

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await _repository.submitExpense(
      amount: double.parse(_amount.text.trim()),
      category: _category,
      date: _date,
      description: _description.text,
      receiptUrl: _receiptUrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result case Failure<ExpenseClaim>(:final message)) {
      setState(() => _error = message);
      return;
    }
    _amount.clear();
    _description.clear();
    _receiptUrl.clear();
    setState(() {
      _category = _categories.first;
      _date = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense claim submitted for approval.')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final employee = AppScope.of(context).data.employee;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Expenses'),
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
                        'Submit an expense',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (employee?.employeeId.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Employee ID: ${employee!.employeeId}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Expense type',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (value) => setState(
                                () => _category = value ?? _categories.first,
                              ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (₹)',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final parsed = double.tryParse((value ?? '').trim());
                          final text = (value ?? '').trim();
                          final decimals = text.contains('.')
                              ? text.split('.').last.length
                              : 0;
                          return parsed == null || parsed <= 0
                              ? 'Enter an amount greater than zero.'
                              : decimals > 2
                              ? 'Use no more than 2 decimal places.'
                              : null;
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        label: Text('Expense date · ${_dateLabel(_date)}'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _description,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Details',
                          hintText: 'Add a short note about this expense',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter expense details.'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _receiptUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Receipt URL (optional)',
                          hintText: 'https://…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ],
                      const SizedBox(height: 10),
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
                          _submitting ? 'Submitting…' : 'Submit for approval',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Expense history',
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
            else if (_claims.isEmpty)
              const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                message: 'Your submitted expense claims will appear here.',
              )
            else
              ..._claims.map(_claimCard),
          ],
        ),
      ),
    );
  }

  Widget _claimCard(ExpenseClaim claim) {
    final status = claim.status.toUpperCase();
    final color = status == 'APPROVED'
        ? AppColors.success
        : status == 'REJECTED'
        ? AppColors.danger
        : AppColors.warning;
    return Card(
      color: AppColors.surface,
      elevation: 0,
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: AppColors.backgroundAlt,
          child: Icon(Icons.receipt_long_rounded, color: AppColors.primary),
        ),
        title: Text(
          claim.category,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_dateLabel(claim.date)} · ${claim.description}${claim.reviewNote?.isNotEmpty == true ? '\nReview: ${claim.reviewNote}' : ''}',
        ),
        isThreeLine: claim.reviewNote?.isNotEmpty == true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${claim.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
