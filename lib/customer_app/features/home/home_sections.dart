import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../state/app_state.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../booking/booking_detail_screen.dart';
import '../booking/booking_screen.dart';
import '../checkups/checkups_screen.dart';
import '../reports/report_detail_screen.dart';
import '../reports/reports_screen.dart';
import '../services/service_detail_screen.dart';
import '../tracking/tracking_screen.dart';
import 'shell_scope.dart';

/// Four shortcut tiles under the header: book, services, reports, checkups.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key, this.activeBookingId});

  final String? activeBookingId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final actions = <_QuickAction>[
      _QuickAction(
        label: 'Book Service',
        icon: Icons.add_task_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BookingScreen())),
      ),
      _QuickAction(
        label: 'Track',
        icon: Icons.my_location_rounded,
        onTap: () {
          if (activeBookingId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No active booking to track'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => TrackingScreen(bookingId: activeBookingId!),
            ),
          );
        },
      ),
      _QuickAction(
        label: 'Reports',
        icon: Icons.insights_rounded,
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen())),
      ),
      _QuickAction(
        label: 'Checkups',
        icon: Icons.science_rounded,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CheckupsScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        AppTheme.gutter,
        AppTheme.gutter,
        0,
      ),
      child: Row(
        children: actions
            .map(
              (action) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      InkWell(
                        onTap: action.onTap,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        child: Container(
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                            border: Border.all(color: AppColors.border),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            action.icon,
                            size: 24,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        action.label,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// Next visit card with live tracking entry point.
class NextVisitSection extends StatelessWidget {
  const NextVisitSection({super.key, this.activeBookingId});

  final String? activeBookingId;

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    final booking = data.activeBooking;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        24,
        AppTheme.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Next Service Visit',
            actionLabel: 'View All',
            onAction: () => ShellScope.maybeOf(context)?.selectTab(2),
          ),
          if (booking == null)
            AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.event_available_outlined,
                title: 'No upcoming visits',
                message: 'Book a service and track it live from here.',
                actionLabel: 'Book Now',
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BookingScreen(),
                  ),
                ),
              ),
            )
          else
            BookingCard(
              booking: booking,
              onTrack: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TrackingScreen(bookingId: booking.id),
                ),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BookingDetailScreen(bookingId: booking.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Latest water report teaser with a health score dial.
class ReportSection extends StatelessWidget {
  const ReportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    final report = data.latestReport;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        24,
        AppTheme.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Latest Water Report',
            actionLabel: 'All Reports',
            onAction: () => ShellScope.maybeOf(context)?.selectTab(1),
          ),
          if (report == null)
            const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.insights_outlined,
                title: 'No reports yet',
                message: 'A report is generated after every service visit.',
              ),
            )
          else
            AppCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReportDetailScreen(reportId: report.id),
                ),
              ),
              child: Row(
                children: [
                  HealthScoreDial(score: report.healthScore, size: 62),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.period,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.summary,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.hint,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Circular score indicator used on the report cards.
class HealthScoreDial extends StatelessWidget {
  const HealthScoreDial({super.key, required this.score, this.size = 56});

  final int score;
  final double size;

  Color get _color => score >= 85
      ? AppColors.success
      : score >= 70
      ? AppColors.warning
      : AppColors.danger;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: score / 100),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: size * 0.09,
                backgroundColor: AppColors.backgroundAlt,
                color: _color,
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              '$score',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: _color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling popular services carousel.
class PopularServicesSection extends StatelessWidget {
  const PopularServicesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    final services = data.services.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        24,
        AppTheme.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Popular Services',
            actionLabel: 'See All',
            onAction: () => ShellScope.maybeOf(context)?.selectTab(1),
          ),
          if (services.isEmpty)
            const AppCard(
              child: EmptyState(
                compact: true,
                icon: Icons.grid_view_outlined,
                title: 'No services available',
                message: 'Pull to refresh or contact support.',
              ),
            )
          else
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: services.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final service = services[index];
                  return ServiceCard(
                    title: service.name,
                    icon: service.icon,
                    priceLabel: service.priceLabel,
                    durationLabel: service.durationLabel,
                    isPopular: service.isPopular,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ServiceDetailScreen(serviceId: service.id),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Fixed-width service card used in the carousel.
class ServiceCard extends StatelessWidget {
  const ServiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.priceLabel,
    required this.durationLabel,
    this.onTap,
    this.isPopular = false,
  });

  final String title;
  final IconData icon;
  final String priceLabel;
  final String durationLabel;
  final VoidCallback? onTap;
  final bool isPopular;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 162,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconTile(icon: icon, size: 40, iconSize: 20),
                const Spacer(),
                if (isPopular)
                  const StatusPill(
                    label: 'Popular',
                    color: AppColors.primary,
                    background: AppColors.mintSoft,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Text(
                title,
                style: textTheme.titleSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              priceLabel,
              style: textTheme.titleSmall?.copyWith(color: AppColors.primary),
            ),
            Text(durationLabel, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Support callout closing out the dashboard.
class SupportBanner extends StatelessWidget {
  const SupportBanner({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      onTap: onTap,
      color: AppColors.mintSoft,
      borderColor: AppColors.mint,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need help?', style: textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Chat with our water experts 24x7',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
}
