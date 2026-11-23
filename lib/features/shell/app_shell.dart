import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../state/app_controller.dart';
import '../../widgets/feedback_views.dart';
import '../../widgets/loading_views.dart';
import '../attendance/attendance_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../history/history_screen.dart';
import '../jobs/jobs_screen.dart';
import '../profile/profile_screen.dart';

/// Bottom-navigation host for the five field-staff tabs (spec §20).
///
/// Attendance is a permanent tab so marking presence is always one tap away.
class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  /// Lets tests and deep links open straight to a given tab.
  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _index = widget.initialIndex;

  static const List<_Tab> _tabs = <_Tab>[
    _Tab('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _Tab('My Jobs', Icons.work_outline_rounded, Icons.work_rounded),
    _Tab('Attendance', Icons.event_available_outlined, Icons.event_available),
    _Tab('History', Icons.history_rounded, Icons.history_rounded),
    _Tab('Profile', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final data = controller.data;

    if (data.loading && data.employee == null) {
      return const Scaffold(
        body: Center(child: LoadingState(message: 'Preparing your day...')),
      );
    }

    if (data.employee == null) {
      return Scaffold(
        body: ErrorState(
          message: data.error ?? 'We could not load your profile.',
          onRetry: controller.retry,
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const <Widget>[
          DashboardScreen(),
          JobsScreen(),
          AttendanceScreen(),
          HistoryScreen(),
          ProfileScreen(),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        index: _index,
        tabs: _tabs,
        onChanged: (value) => setState(() => _index = value),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.tabs,
    required this.onChanged,
  });

  final int index;
  final List<_Tab> tabs;
  final ValueChanged<int> onChanged;

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
            children: List<Widget>.generate(tabs.length, (i) {
              final tab = tabs[i];
              final selected = i == index;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        selected ? tab.activeIcon : tab.icon,
                        size: 22,
                        color: selected ? AppColors.primary : AppColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: selected ? AppColors.primary : AppColors.muted,
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
