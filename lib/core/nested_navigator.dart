import 'package:flutter/material.dart';

/// A nested [Navigator] that also receives the system back button / gesture.
///
/// The OS back dispatch only consults the root navigator (see
/// `WidgetsAppState.didPopRoute`): routes pushed onto a nested navigator are
/// invisible to it. Without this widget, a screen pushed on a nested navigator
/// (e.g. the booking wizard below `CustomerScope`) is skipped by the system
/// back: the root host route is first in its stack, so it bubbles and the app
/// closes — even though the AppBar's back button, which pops the nearest
/// navigator, works.
///
/// This widget keeps both paths consistent:
///
///  * While it has pushed routes, a [PopScope] vetoes pops of the enclosing
///    root route, so the root navigator reports [RoutePopDisposition.doNotPop]
///    instead of popping wholesale (guest host case) or bubbling into an app
///    exit (signed-in host case). The veto callback then pops the nested top
///    route, and on predictive-back devices the OS is told the framework
///    handles the gesture.
///  * A [WidgetsBindingObserver] is kept as a fallback for SDKs where a
///    vetoed root pop lets the back dispatch fall through to the observers
///    instead of reporting it as handled.
///
/// At the nested shell root nothing is vetoed: back then pops a guest host
/// back to the welcome screen, or closes the app from a first route, exactly
/// like a plain navigator.
class NestedNavigator extends StatefulWidget {
  const NestedNavigator({super.key, required this.onGenerateRoute});

  /// Passed through to the underlying [Navigator].
  final RouteFactory onGenerateRoute;

  @override
  State<NestedNavigator> createState() => _NestedNavigatorState();
}

class _NestedNavigatorState extends State<NestedNavigator>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _NestedNavObserver _observer = _NestedNavObserver(_syncCanPop);
  bool _nestedCanPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Fallback for SDK dispatch orders where the vetoed root pop does not stop
  /// the back dispatch: pops the nested top route and reports the back as
  /// handled. At the nested shell root it does nothing, letting the root
  /// navigator proceed normally.
  @override
  Future<bool> didPopRoute() async {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    navigator.pop();
    return true;
  }

  void _syncCanPop() {
    _applyCanPop();
    if (!_nestedCanPop || !mounted) return;
    // A popped route keeps counting as "present" until its exit transition
    // finishes, so canPop lags behind the observer notification. Re-check on
    // each frame until it settles; an idle navigator stops scheduling frames,
    // which parks the chain on the correct value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncCanPop();
    });
  }

  void _applyCanPop() {
    final canPop = _navigatorKey.currentState?.canPop() ?? false;
    if (!mounted || canPop == _nestedCanPop) return;
    setState(() => _nestedCanPop = canPop);
  }

  void _popNestedIfPossible() {
    final navigator = _navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return;
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_nestedCanPop,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        // A vetoed pop (didPop == false) is how the root navigator reports
        // "handled" on current SDKs - see NavigatorState.maybePop, which
        // answers doNotPop with true. That would swallow the back event here,
        // so the nested top route is popped right from the veto instead. The
        // didPopRoute observer above covers SDKs where the dispatch falls
        // through instead.
        if (!didPop) _popNestedIfPossible();
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: widget.onGenerateRoute,
        observers: <NavigatorObserver>[_observer],
      ),
    );
  }
}

/// Reports history changes of the nested navigator so the [PopScope] above
/// stays in sync.
class _NestedNavObserver extends NavigatorObserver {
  _NestedNavObserver(this._onChange);

  final VoidCallback _onChange;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChange();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChange();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _onChange();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _onChange();
}