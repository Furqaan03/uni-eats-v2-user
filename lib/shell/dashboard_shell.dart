import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/pill_nav.dart';
import '../features/cart/providers/cart_provider.dart';
import '../features/cart/widgets/resume_cart_prompt.dart';

class DashboardShell extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardShell({super.key, required this.navigationShell});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  int _lastKnownIndex = 0;
  final List<int> _history = [0];
  bool _checkedResumeCart = false;

  @override
  void initState() {
    super.initState();
    // One-shot, fires once the dashboard (i.e. a real app session, post-auth)
    // first mounts — covers exactly the "reopened after a force-close" case
    // without re-prompting on every tab switch.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _checkedResumeCart) return;
      _checkedResumeCart = true;
      maybeShowResumeCartPrompt(context, ref);
    });
  }

  void _recordVisit(int index) {
    if (index == _lastKnownIndex) return;
    _history.remove(index);
    _history.add(index);
    _lastKnownIndex = index;
  }

  void _goToTab(NavTab tab) {
    final newIndex = _indexForTab(tab);
    if (newIndex == widget.navigationShell.currentIndex) return;
    setState(() => _recordVisit(newIndex));
    widget.navigationShell.goBranch(newIndex);
  }

  void _handlePop() {
    if (_history.length > 1) {
      setState(() => _history.removeLast());
      widget.navigationShell.goBranch(_history.last);
    } else {
      // On home with no prior tab — exit the app.
      SystemNavigator.pop();
    }
  }

  int _indexForTab(NavTab tab) => switch (tab) {
        NavTab.home => 0,
        NavTab.map => 1,
        NavTab.cart => 2,
        NavTab.orders => 3,
        NavTab.profile => 4,
      };

  NavTab _tabForIndex(int index) => switch (index) {
        0 => NavTab.home,
        1 => NavTab.map,
        2 => NavTab.cart,
        3 => NavTab.orders,
        4 => NavTab.profile,
        _ => NavTab.home,
      };

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;

    // Catch external navigations (context.go, notifications, post-checkout).
    if (currentIndex != _lastKnownIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _recordVisit(currentIndex));
      });
    }

    final cartCount = ref.watch(cartItemCountProvider);

    return PopScope(
      // Always false — we handle exit manually via SystemNavigator.pop().
      // This avoids the Android predictive-back race where the OS queries
      // canPop before our setState rebuild fires and exits the app prematurely.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        body: widget.navigationShell,
        extendBody: true,
        bottomNavigationBar: PillNavBar(
          currentTab: _tabForIndex(currentIndex),
          cartItemCount: cartCount,
          onTabTap: _goToTab,
        ),
      ),
    );
  }
}
