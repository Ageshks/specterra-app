import 'package:flutter/widgets.dart';

/// Lets any descendant switch the tab shown by `HomeShell`.
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.selectedIndex,
    required this.selectTab,
    required this.goToTab,
    required super.child,
  });

  final int selectedIndex;
  final void Function(int index) selectTab;

  /// Switches tab and returns to the shell root. Supplied by `HomeShell`,
  /// which owns the navigator, so any pushed route can call it.
  final void Function(int index) goToTab;

  static ShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      oldWidget.selectedIndex != selectedIndex;
}
