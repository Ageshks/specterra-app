import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/water_service.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/filter_widgets.dart';
import '../../widgets/loading_views.dart';
import '../../widgets/service_tile.dart';
import '../auth/login_screen.dart';
import 'service_detail_screen.dart';

/// Services list with category chips and search, per the reference design.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  ServiceCategory? _category;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<WaterService> _filter(List<WaterService> services) {
    final query = _query.trim().toLowerCase();
    return services.where((service) {
      final matchesCategory =
          _category == null || service.category == _category;
      final matchesQuery =
          query.isEmpty ||
          service.name.toLowerCase().contains(query) ||
          service.description.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;
    final services = _filter(data.services);
    final categories = ServiceCategory.values;
    // Guests browse without a bearer token; signed-in users always have one.
    final isGuest = !controller.repository.api.hasToken;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Our Services'),
        actions: [
          if (data.services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${services.length} services',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (isGuest)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.gutter,
                14,
                AppTheme.gutter,
                0,
              ),
              child: _GuestServicesBanner(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.gutter,
              14,
              AppTheme.gutter,
              10,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search for a service',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (data.services.isNotEmpty)
            FilterPillRow(
              labels: <String>['All', ...categories.map((c) => c.label)],
              selectedIndex: _category == null
                  ? 0
                  : categories.indexOf(_category!) + 1,
              onSelected: (index) => setState(() {
                _category = index == 0 ? null : categories[index - 1];
              }),
            ),
          const SizedBox(height: 8),
          Expanded(child: _body(context, services)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, List<WaterService> services) {
    final data = CustomerScope.of(context).data;

    if (data.isLoadingData && data.services.isEmpty) {
      return const SkeletonList(itemCount: 5, itemHeight: 78);
    }
    if (data.dataError != null && data.services.isEmpty) {
      return ErrorState(
        message: data.dataError!,
        onRetry: CustomerScope.of(context).reload,
      );
    }
    if (services.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No services found',
        message: _query.isEmpty
            ? 'No services match this category yet.'
            : 'We could not find anything for "$_query".',
        actionLabel: 'Clear filters',
        onAction: () {
          _searchController.clear();
          setState(() {
            _query = '';
            _category = null;
          });
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gutter,
        8,
        AppTheme.gutter,
        28,
      ),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final service = services[index];
        return ServiceTile(
          title: service.name,
          subtitle: service.description,
          icon: service.icon,
          priceLabel: '${service.priceLabel} • ${service.durationLabel}',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ServiceDetailScreen(serviceId: service.id),
            ),
          ),
        );
      },
    );
  }
}

/// Shown above the catalog when browsing as a guest: services can be booked
/// directly, and signing in is optional (reports/history only).
class _GuestServicesBanner extends StatelessWidget {
  const _GuestServicesBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Browsing as a guest — tap any service to book without an '
              'account.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
            ),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }
}
