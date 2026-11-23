import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../widgets/action_widgets.dart';

/// Screen for requesting overtime.
class OvertimeRequestScreen extends StatefulWidget {
  const OvertimeRequestScreen({
    required this.eligibility,
    required this.onSubmit,
    Key? key,
  }) : super(key: key);

  final OvertimeEligibility eligibility;
  final Function({
    required DateTime date,
    required String reason,
    required int? requestedMinutes,
  }) onSubmit;

  @override
  State<OvertimeRequestScreen> createState() => _OvertimeRequestScreenState();
}

class _OvertimeRequestScreenState extends State<OvertimeRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  late String _reason;
  late int _requestedMinutes;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.eligibility.date;
    _reason = '';
    _requestedMinutes = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Overtime'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date: ${Formatters.dayMonthYear(_selectedDate)}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<DateTime>(
                value: _selectedDate,
                onChanged: (DateTime? newValue) {
                  setState(() => _selectedDate = newValue!);
                },
                decoration: const InputDecoration(
                  labelText: 'Work Date',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Select a date' : null,
                // Only allow today or future dates
                items: <DateTime>[DateTime.now()].map<DropdownMenuItem<DateTime>>((DateTime value) {
                  return DropdownMenuItem<DateTime>(
                    value: value,
                    child: Text(Formatters.dayMonthYear(value)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Enter a reason' : null,
                onSaved: (String? value) => _reason = value ?? '',
              ),
              const SizedBox(height: 16),
              const ListTile(
                title: Text('Requested overtime minutes'),
                trailing: Icon(Icons.remove),
                onTap: null,
              ),
              const ListTile(
                title: Text('Increase by 15 min'),
                trailing: Icon(Icons.add),
                onTap: null,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Submit Overtime Request',
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    widget.onSubmit(
                      date: _selectedDate,
                      reason: _reason.trim(),
                      requestedMinutes: _requestedMinutes > 0
                          ? _requestedMinutes
                          : null,
                    );
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                },
                busy: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}