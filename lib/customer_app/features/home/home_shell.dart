import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../bookings/bookings_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_screen.dart';
import '../services/services_screen.dart';
import 'shell_scope.dart';

/// Root scaffold of the signed-in experience with a five item bottom bar.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialIndex = 0, this.guestMode = false});

  final int initialIndex;
  final bool guestMode;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialIndex;

  static const List<_ShellDestination> _destinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _ShellDestination(
      label: 'Services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _ShellDestination(
      label: 'Bookings',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
    _ShellDestination(
      label: 'History',
      icon: Icons.history_rounded,
      activeIcon: Icons.history_rounded,
    ),
    _ShellDestination(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  static const List<_ShellDestination> _guestDestinations = <_ShellDestination>[
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _ShellDestination(
      label: 'Services',
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
    ),
    _ShellDestination(
      // Guests book without an account, so this tab shows their session
      // bookings (upcoming by default) instead of completed-only history.
      label: 'My Bookings',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month_rounded,
    ),
  ];

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    ServicesScreen(),
    BookingsScreen(),
    BookingsScreen(initialTab: 1),
    ProfileScreen(),
  ];

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  /// Returns to the shell root and switches tab, used by pushed routes.
  void _goToTab(int index) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _select(index);
  }

  @override
  Widget build(BuildContext context) {
    final destinations = widget.guestMode ? _guestDestinations : _destinations;
    final screens = widget.guestMode
        ? const <Widget>[
            HomeScreen(guestMode: true),
            ServicesScreen(),
            BookingsScreen(title: 'My Bookings'),
          ]
        : _screens;

    return ShellScope(
      selectedIndex: _index,
      selectTab: _select,
      goToTab: _goToTab,
      child: Scaffold(
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: _BottomNavBar(
          index: _index,
          destinations: destinations,
          onSelected: _select,
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.index,
    required this.destinations,
    required this.onSelected,
  });

  final int index;
  final List<_ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List<Widget>.generate(destinations.length, (i) {
              final destination = destinations[i];
              final isActive = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onSelected(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.mintSoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusPill,
                          ),
                        ),
                        child: Icon(
                          isActive ? destination.activeIcon : destination.icon,
                          size: 21,
                          color: isActive ? AppColors.primary : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        destination.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 10.5,
                          color: isActive ? AppColors.primary : AppColors.muted,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
