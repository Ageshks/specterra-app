import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/supporting_models.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';

/// Full water report with per-parameter bars and recommendations.
class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({super.key, required this.reportId});

  final String reportId;

  WaterReport? _resolve(List<WaterReport> reports) {
    for (final report in reports) {
      if (report.id == reportId) return report;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    final report = _resolve(data.reports);

    if (report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report')),
        body: EmptyState(
          icon: Icons.description_outlined,
          title: 'Report not found',
          message: 'This report is no longer available.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final unhealthy = report.metrics.where((m) => !m.isHealthy).toList();

    return Scaffold(
      appBar: AppBar(title: Text(report.period)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          32,
        ),
        children: [
          _ScoreCard(report: report),
          const SizedBox(height: 18),
          Text('Tested parameters', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: report.metrics
                  .map((m) => _MetricBar(metric: m))
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          Text('Summary', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          AppCard(child: Text(report.summary, style: textTheme.bodyMedium)),
          const SizedBox(height: 18),
          Text('Recommendations', style: textTheme.titleMedium),
          const SizedBox(height: 10),
          if (unhealthy.isEmpty)
            const InfoNote(
              icon: Icons.verified_rounded,
              title: 'All parameters healthy',
              message: 'No action needed. Keep your next checkup on schedule.',
            )
          else
            ...unhealthy.map(
              (metric) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InfoNote(
                  icon: Icons.warning_amber_rounded,
                  title: '${metric.label} needs attention',
                  message:
                      '${metric.value} ${metric.unit} is outside the '
                      'recommended range. Book a service to correct it.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          const InfoNote(
            icon: Icons.info_outline_rounded,
            message:
                'Reports are generated after every service visit and free '
                'water checkup. PDF download is available from your inbox.',
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.report});

  final WaterReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: report.healthScore / 100,
                    strokeWidth: 10,
                    backgroundColor: AppColors.backgroundAlt,
                    color: AppColors.primary,
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${report.healthScore}',
                      style: textTheme.displaySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text('out of 100', style: textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(report.title, style: textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '${report.period} • Issued ${report.issuedDate} • '
            '${report.fileSizeMb} MB',
            style: textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.metric});

  final WaterMetric metric;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = metric.isHealthy ? AppColors.primary : AppColors.warning;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  metric.label,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${metric.value} ${metric.unit}',
                style: textTheme.titleSmall?.copyWith(color: color),
              ),
              const SizedBox(width: 8),
              Icon(
                metric.isHealthy
                    ? Icons.check_circle_rounded
                    : Icons.error_rounded,
                size: 16,
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: metric.percentage.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.backgroundAlt,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
