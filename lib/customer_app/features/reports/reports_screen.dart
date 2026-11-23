import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/supporting_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';
import 'report_detail_screen.dart';

/// Water quality reports with the latest health score highlighted.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;
    final latest = data.latestReport;

    return Scaffold(
      appBar: AppBar(title: const Text('Water Reports')),
      body: _body(context, controller, data.reports, latest),
    );
  }

  Widget _body(
    BuildContext context,
    AppController controller,
    List<WaterReport> reports,
    WaterReport? latest,
  ) {
    final data = controller.data;

    if (data.isLoadingData && reports.isEmpty) {
      return const SkeletonList(itemCount: 4, itemHeight: 108);
    }
    if (data.dataError != null && reports.isEmpty) {
      return ErrorState(message: data.dataError!, onRetry: controller.reload);
    }
    if (reports.isEmpty) {
      return const EmptyState(
        icon: Icons.insights_outlined,
        title: 'No reports yet',
        message:
            'Your first water quality report appears after your first '
            'service visit.',
      );
    }

    return RefreshIndicator(
      onRefresh: controller.reload,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          28,
        ),
        itemCount: reports.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) return _ScoreBanner(report: latest!);
          final report = reports[index - 1];
          return _ReportCard(
            report: report,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReportDetailScreen(reportId: report.id),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScoreBanner extends StatelessWidget {
  const _ScoreBanner({required this.report});

  final WaterReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scoreColor = report.healthScore >= 85
        ? AppColors.primary
        : report.healthScore >= 70
        ? AppColors.warning
        : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.tileGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(
                    value: report.healthScore / 100,
                    strokeWidth: 7,
                    backgroundColor: Colors.white,
                    color: scoreColor,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${report.healthScore}',
                      style: textTheme.headlineSmall?.copyWith(
                        color: scoreColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('score', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Water health', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Your ${report.period} water is '
                  '${report.healthScore >= 85 ? 'safe to drink' : 'fair, keep testing'}.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                StatusPill(
                  label: '${report.metrics.length} parameters',
                  color: AppColors.primary,
                  background: Colors.white,
                  icon: Icons.science_outlined,
                  dense: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report, required this.onTap});

  final WaterReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconTile(
            icon: Icons.description_outlined,
            size: 46,
            iconSize: 22,
            background: AppColors.mintSoft,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.title, style: textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  '${report.period} • Issued ${report.issuedDate}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                StatusPill(
                  label: 'Health ${report.healthScore}/100',
                  color: AppColors.primary,
                  background: AppColors.mintSoft,
                  dense: true,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
