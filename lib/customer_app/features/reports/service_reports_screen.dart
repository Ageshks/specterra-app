import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/specterra_repository.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';

class ServiceReportsScreen extends StatefulWidget {
  const ServiceReportsScreen({super.key});
  @override
  State<ServiceReportsScreen> createState() => _ServiceReportsScreenState();
}

class _ServiceReportsScreenState extends State<ServiceReportsScreen> {
  final _reports = <CustomerServiceReport>[];
  bool _loading = true, _loadingMore = false;
  String? _error;
  int _page = 1, _totalPages = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() { _loading = true; _error = null; _page = 1; });
    } else {
      setState(() => _loadingMore = true);
    }
    try {
      final result = await CustomerScope.of(context).repository.fetchCustomerServiceReports(page: reset ? 1 : _page + 1);
      if (!mounted) return;
      setState(() {
        if (reset) _reports.clear();
        _reports.addAll(result.reports);
        _page = result.page; _totalPages = result.totalPages; _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e is DataFailure ? e.message : 'Could not load service reports.');
    } finally {
      if (mounted) setState(() { _loading = false; _loadingMore = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Service Reports')),
      body: _loading && _reports.isEmpty
          ? const SkeletonList(itemCount: 4, itemHeight: 108)
          : _error != null && _reports.isEmpty
              ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
              : _reports.isEmpty && _page >= _totalPages
                  ? const EmptyState(icon: Icons.description_outlined, title: 'No approved reports yet', message: 'Approved reports from your completed service visits will appear here.')
                  : RefreshIndicator(
                      onRefresh: () => _load(reset: true),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppTheme.gutter),
                        itemCount: _reports.length + (_page < _totalPages ? 1 : 0) + (_error != null ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index < _reports.length) return _ServiceReportCard(report: _reports[index], onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ServiceReportDetailScreen(report: _reports[index]))));
                          if (_error != null) return ErrorState(message: _error!, onRetry: () => _load(reset: false));
                          return Center(child: Padding(padding: const EdgeInsets.all(12), child: _loadingMore ? const CircularProgressIndicator() : OutlinedButton(onPressed: () => _load(reset: false), child: const Text('Load more reports'))));
                        },
                      ),
                    ),
    );
  }
}

class _ServiceReportCard extends StatelessWidget {
  const _ServiceReportCard({required this.report, required this.onTap});
  final CustomerServiceReport report;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => AppCard(onTap: onTap, child: Row(children: [
    IconTile(icon: Icons.build_circle_outlined, size: 46, iconSize: 22, background: AppColors.mintSoft),
    const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(report.serviceName, style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 3), Text(report.reportNumber, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 7), const StatusPill(label: 'Approved', color: AppColors.primary, background: AppColors.mintSoft, dense: true),
    ])), const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
  ]));
}

class ServiceReportDetailScreen extends StatelessWidget {
  const ServiceReportDetailScreen({super.key, required this.report});
  final CustomerServiceReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Scaffold(appBar: AppBar(title: Text(report.reportNumber)), body: ListView(padding: const EdgeInsets.all(AppTheme.gutter), children: [
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(report.serviceName, style: theme.titleLarge), const SizedBox(height: 10),
        const StatusPill(label: 'Approved', color: AppColors.primary, background: AppColors.mintSoft, dense: true),
        const SizedBox(height: 12), Text('Booking ${report.bookingNumber.isEmpty ? '—' : report.bookingNumber}\nWork order ${report.workOrderNumber.isEmpty ? '—' : report.workOrderNumber}', style: theme.bodyMedium),
        if (report.submittedAt != null) ...[const SizedBox(height: 8), Text('Submitted ${_date(report.submittedAt!)}', style: theme.bodySmall)],
      ])),
      const SizedBox(height: 18),
      _section(context, 'Work summary', report.workSummary),
      _section(context, 'Work performed', report.workPerformed),
      _section(context, 'Issues found', report.issuesFound),
      _section(context, 'Materials used', report.materialsUsed),
      _section(context, 'Recommendations', report.recommendations),
      _section(context, 'Completion remarks', report.completionRemarks),
      if (report.technician != null || report.reviewer != null) ...[
        Text('People', style: theme.titleMedium), const SizedBox(height: 10),
        AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (report.technician != null) Text('Technician  ${report.technician}'), if (report.technician != null && report.reviewer != null) const SizedBox(height: 8), if (report.reviewer != null) Text('Reviewed by  ${report.reviewer}')])) ,
      ],
      if (report.photos.isNotEmpty) ...[
        const SizedBox(height: 18), Text('Service photos', style: theme.titleMedium), const SizedBox(height: 10),
        ...report.photos.map((photo) => Padding(padding: const EdgeInsets.only(bottom: 12), child: ClipRRect(borderRadius: BorderRadius.circular(AppTheme.radiusMd), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Image.network(photo.imageUrl, width: double.infinity, height: 220, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(height: 160, color: AppColors.backgroundAlt, alignment: Alignment.center, child: const Icon(Icons.broken_image_outlined)), loadingBuilder: (context, child, progress) => progress == null ? child : const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),), if (photo.caption != null && photo.caption!.isNotEmpty) Padding(padding: const EdgeInsets.all(10), child: Text(photo.caption!))])))),
      ],
    ]));
  }

  Widget _section(BuildContext context, String title, String? text) => text == null || text.trim().isEmpty ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8), AppCard(child: Text(text, style: Theme.of(context).textTheme.bodyMedium))]));
  static String _date(String value) { final date = DateTime.tryParse(value)?.toLocal(); return date == null ? value : '${date.day}/${date.month}/${date.year}'; }
}
