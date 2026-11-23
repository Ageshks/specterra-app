import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/feedback_views.dart';
import '../attendance/overtime_history_screen.dart';
import '../jobs/jobs_screen.dart';
import '../expenses/expense_claims_screen.dart';
import '../transfer/transfer_history_screen.dart';

/// "History" tab (spec §20).
///
/// Combines the two histories a technician cares about: completed work and
/// transfer requests, with overtime as a third lane.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _segment = 0;

  static const List<String> _labels = <String>[
    'Completed Work',
    'Transfer Requests',
    'Overtime',
    'Expenses',
  ];

  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('History'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              0,
              AppTheme.gutter,
              12,
            ),
            child: Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == _labels.length - 1 ? 0 : 8,
                      ),
                      child: Material(
                        color: _segment == i
                            ? AppColors.primary
                            : AppColors.backgroundAlt,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        child: InkWell(
                          onTap: () => setState(() => _segment = i),
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              _labels[i],
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _segment == i
                                    ? Colors.white
                                    : AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (_segment) {
              0 => _CompletedList(jobs: data.completedJobs),
              1 => _TransferList(requests: data.myTransfers),
              2 => const OvertimeHistoryScreen(),
              _ => const ExpenseClaimsScreen(),
            },
          ),
        ],
      ),
    );
  }
}

class _CompletedList extends StatelessWidget {
  const _CompletedList({required this.jobs});

  final List<WorkJob> jobs;

  @override
  Widget build(BuildContext context) {
    if (jobs.isEmpty) {
      return const EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'No completed work',
        message: 'Work you finish will be listed here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        24,
      ),
      itemCount: jobs.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: JobCard(job: jobs[index]),
      ),
    );
  }
}

class _TransferList extends StatelessWidget {
  const _TransferList({required this.requests});

  final List<TransferRequest> requests;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const EmptyState(
        icon: Icons.swap_horiz_rounded,
        title: 'No transfers yet',
        message: 'Transfer requests you raise will be listed here.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        14,
        AppTheme.gutter,
        24,
      ),
      itemCount: requests.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TransferHistoryCard(request: requests[index]),
      ),
    );
  }
}
