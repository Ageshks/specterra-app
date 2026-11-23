import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/booking.dart';
import '../../state/app_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/home_header.dart';
import '../../widgets/loading_views.dart';
import '../auth/login_screen.dart';
import '../booking/booking_screen.dart';
import '../notifications/notifications_screen.dart';
import '../tracking/guest_tracking_lookup_screen.dart';
import 'home_sections.dart';
import 'shell_scope.dart';

/// Customer dashboard: greeting, quick actions, next visit and shortcuts.
///
/// When [guestMode] is true the screen is rendered for an anonymous visitor:
/// no account data is referenced, the primary action is booking a service
/// without logging in, and shortcuts point to guest-safe destinations.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.guestMode = false});

  final bool guestMode;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final controller = CustomerScope.of(context);
    final data = controller.data;
    final activeBooking = data.activeBooking;

    if (data.isLoadingData &&
        data.bookings.isEmpty &&
        data.services.isEmpty) {
      return _loadingScaffold();
    }

    // Guests never fetch a profile, so a dataError only applies to
    // signed-in customers. Guests always fall through to the body.
    if (!guestMode && data.dataError != null && data.bookings.isEmpty) {
      return _errorScaffold(context, data);
    }

    return _buildBody(context, data, activeBooking);
  }

  Widget _loadingScaffold() {
    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            greeting: _greeting,
            name: guestMode ? 'Welcome, Guest' : 'Loading…',
            subtitle: guestMode ? 'Book services without an account.' : null,
            initials: guestMode ? 'G' : '…',
          ),
          const Expanded(child: SkeletonList(itemCount: 3, itemHeight: 130)),
        ],
      ),
    );
  }

  Widget _errorScaffold(BuildContext context, AppData data) {
    final customer = data.customer;
    return Scaffold(
      body: Column(
        children: [
          HomeHeader(
            greeting: _greeting,
            name: customer?.firstName ?? 'there',
            initials: customer?.initials ?? '…',
          ),
          Expanded(
            child: ErrorState(
              message: data.dataError!,
              onRetry: () => CustomerScope.of(context).reload(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppData data,
    Booking? activeBooking,
  ) {
    final customer = data.customer;
    // Sections already include their own horizontal padding via the
    // widgets; the CTA and perks cards wrap it themselves below.
    final sections = guestMode
        ? <Widget>[
            const _GuestBookingCta(),
            const PopularServicesSection(),
            const _GuestPerksSection(),
          ]
        : <Widget>[
            const SizedBox(height: 4),
            QuickActionsSection(activeBookingId: activeBooking?.id),
            NextVisitSection(activeBookingId: activeBooking?.id),
            const ReportSection(),
            const PopularServicesSection(),
            const SizedBox(height: 4),
            SupportBanner(
              onTap: () => ShellScope.maybeOf(context)?.selectTab(4),
            ),
          ];

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.gutter,
                  AppTheme.gutter,
                  AppTheme.gutter,
                  12,
                ),
                child: HomeHeader(
                  greeting: _greeting,
                  name: guestMode
                      ? 'Welcome, Guest'
                      : (customer?.firstName ?? 'there'),
                  subtitle: guestMode
                      ? 'Book services without an account.'
                      : customer?.plan,
                  initials: guestMode ? 'G' : (customer?.initials ?? '…'),
                  unreadCount: guestMode ? 0 : data.unreadNotificationCount,
                  onNotifications: guestMode
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        ),
                  onAvatar: guestMode
                      ? null
                      : () => ShellScope.maybeOf(context)?.selectTab(4),
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate.fixed([
                for (final section in sections)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.gutter,
                    ),
                    child: section,
                  ),
                const SizedBox(height: 24),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent "Book a Service" call-to-action that is always available to
/// guests. It opens the booking flow directly — no login required.
class _GuestBookingCta extends StatelessWidget {
  const _GuestBookingCta();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        color: AppColors.primary,
        borderColor: AppColors.primaryDark,
        padding: const EdgeInsets.all(18),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const BookingScreen()),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_task_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Book a Service',
                    style: textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'No account needed — request a visit in under a minute.',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reassurance card shown to guests: booking works without an account and
/// existing requests can still be tracked or found after signing in.
class _GuestPerksSection extends StatelessWidget {
  const _GuestPerksSection();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Book without logging in',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Browse the full service list, pick a date and confirm — your '
              'name and mobile number are all we need. Create an account '
              'anytime to see reports and history in one place.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const GuestTrackingLookupScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.track_changes_rounded, size: 18),
                    label: const Text('Track booking'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LoginScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
