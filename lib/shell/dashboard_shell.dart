import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/pill_nav.dart';
import '../features/cart/providers/cart_provider.dart';

class DashboardShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const DashboardShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final cartCount = ref.watch(cartItemCountProvider);
          return PillNavBar(
            currentTab: _tabForIndex(navigationShell.currentIndex),
            cartItemCount: cartCount,
          );
        },
      ),
    );
  }

  NavTab _tabForIndex(int index) {
    return switch (index) {
      0 => NavTab.home,
      1 => NavTab.map,
      2 => NavTab.cart,
      3 => NavTab.orders,
      4 => NavTab.profile,
      _ => NavTab.home,
    };
  }
}
