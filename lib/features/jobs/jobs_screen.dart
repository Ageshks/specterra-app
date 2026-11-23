import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../state/app_controller.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/staff_widgets.dart';
import 'job_details_screen.dart';
import 'company_calendar_screen.dart';
import '../billing/billing_screens.dart';

/// "My Jobs" list (spec §19, §20).
///
/// Segmented by lifecycle stage so the technician always knows what needs
/// attention next.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  int _segment = 0;

  static const List<({String label, IconData icon})> _segments =
      <({String label, IconData icon})>[
        (label: 'Assigned', icon: Icons.assignment_outlined),
        (label: 'In Progress', icon: Icons.play_circle_outline_rounded),
        (label: 'Done / Review', icon: Icons.check_circle_outline_rounded),
      ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;

    final jobs = switch (_segment) {
      0 => [...data.assignedJobs, ...data.acceptedJobs],
      1 => data.activeJobs,
      _ => [...data.completedJobs, ...data.reportReviewJobs],
    }..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Jobs'),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Billing history',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BillingHistoryScreen(),
              ),
            ),
          ),
          if (AppScope.of(context).repository.isSupervisor)
            IconButton(
              tooltip: 'Billing approvals',
              icon: const Icon(Icons.fact_check_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BillingApprovalScreen(),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Company calendar',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CompanyCalendarScreen(),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          JobSegmentBar(
            segments: _segments,
            index: _segment,
            onChanged: (value) => setState(() => _segment = value),
          ),
          Expanded(child: _JobList(jobs: jobs)),
        ],
      ),
    );
  }
}

class _JobList extends StatelessWidget {
  const _JobList({required this.jobs});

  final List<WorkJob> jobs;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);

    if (jobs.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nothing here yet',
              message: 'Work orders assigned to you will appear in this list.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          4,
          AppTheme.gutter,
          24,
        ),
        itemCount: jobs.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: JobCard(job: jobs[index]),
        ),
      ),
    );
  }
}

class JobSegmentBar extends StatelessWidget {
  const JobSegmentBar({
    super.key,
    required this.segments,
    required this.index,
    required this.onChanged,
  });

  final List<({String label, IconData icon})> segments;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        0,
        AppTheme.gutter,
        12,
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == segments.length - 1 ? 0 : 8,
                ),
                child: Material(
                  color: i == index
                      ? AppColors.primary
                      : AppColors.backgroundAlt,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: InkWell(
                    onTap: () => onChanged(i),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Column(
                        children: [
                          Icon(
                            segments[i].icon,
                            size: 18,
                            color: i == index ? Colors.white : AppColors.muted,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            segments[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: i == index
                                  ? Colors.white
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable work-order summary card.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, this.showDate = true});

  final WorkJob job;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JobDetailsScreen(jobId: job.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  job.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.work(job.status, dense: true),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            job.customerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            job.serviceType,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.inkSoft,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppColors.muted,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${Formatters.time(job.scheduledAt)}'
                  '${showDate ? ' • ${Formatters.dayMonthYear(job.scheduledAt)}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge.priority(job.priority, dense: true),
            ],
          ),
        ],
      ),
    );
  }
}
