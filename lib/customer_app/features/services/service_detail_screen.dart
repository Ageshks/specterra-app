import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/water_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../booking/booking_screen.dart';

/// Service detail with inclusions, pricing and a sticky booking bar.
class ServiceDetailScreen extends StatelessWidget {
  const ServiceDetailScreen({super.key, required this.serviceId});

  final String serviceId;

  WaterService? _resolve(List<WaterService> services) {
    for (final service in services) {
      if (service.id == serviceId) return service;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final data = CustomerScope.of(context).data;
    final service = _resolve(data.services);

    if (service == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Service')),
        body: EmptyState(
          icon: Icons.water_damage_outlined,
          title: 'Service unavailable',
          message: 'This service is no longer offered. Please browse others.',
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).maybePop(),
        ),
      );
    }

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Service Details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          AppTheme.gutter,
          AppTheme.gutter,
          28,
        ),
        children: [
          _HeroBanner(service: service),
          const SizedBox(height: 18),
          Text(service.name, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(service.description, style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.schedule_rounded,
                  label: 'Duration',
                  value: service.durationLabel,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _StatTile(
                  icon: Icons.star_rounded,
                  label: 'Rating',
                  value: '4.8 / 5',
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Served',
                  value: '1.2k+',
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text('What is included', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Column(
              children: service.includes
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(item, style: textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 22),
          Text('Service guarantee', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          const _GuaranteeRow(
            icon: Icons.verified_user_outlined,
            title: 'ISO certified technicians',
            subtitle: 'Trained and background verified engineers',
          ),
          const _GuaranteeRow(
            icon: Icons.verified_user_rounded,
            title: '90 day service warranty',
            subtitle: 'Free re-visit if the issue persists',
          ),
          const _GuaranteeRow(
            icon: Icons.payments_outlined,
            title: 'Transparent pricing',
            subtitle: 'No hidden charges, pay after service',
          ),
        ],
      ),
      bottomNavigationBar: _BookingBar(service: service),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.service});

  final WaterService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 168,
      decoration: BoxDecoration(
        gradient: AppColors.tileGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppColors.mint),
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            right: -24,
            bottom: -30,
            child: Icon(
              service.icon,
              size: 150,
              color: AppColors.primary.withValues(alpha: 0.06),
            ),
          ),
          IconTile(
            icon: service.icon,
            size: 84,
            iconSize: 40,
            radius: AppTheme.radiusLg,
            background: Colors.white,
          ),
          if (service.isPopular)
            Positioned(
              top: 12,
              right: 12,
              child: StatusPill(
                label: 'Most booked',
                color: AppColors.primary,
                background: Colors.white,
                icon: Icons.trending_up_rounded,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: textTheme.titleSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 40, iconSize: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingBar extends StatelessWidget {
  const _BookingBar({required this.service});

  final WaterService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        12,
        AppTheme.gutter,
        12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Starts at', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  service.priceLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        BookingScreen(preselectedServiceId: service.id),
                  ),
                ),
                child: const Text('Book Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
