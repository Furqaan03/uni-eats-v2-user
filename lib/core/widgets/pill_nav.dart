import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';

enum NavTab { home, map, cart, orders, profile }

class PillNavBar extends StatelessWidget {
  static const double height = 84;

  final NavTab currentTab;
  final int cartItemCount;

  const PillNavBar({
    super.key,
    required this.currentTab,
    this.cartItemCount = 0,
  });

  void _onTap(BuildContext context, NavTab tab) {
    if (tab == currentTab) return;
    switch (tab) {
      case NavTab.home:
        context.go('/home');
      case NavTab.map:
        context.go('/tracking');
      case NavTab.cart:
        context.go('/cart');
      case NavTab.orders:
        context.go('/orders');
      case NavTab.profile:
        context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final inactiveColor = isDark ? AppColors.darkTextMuted : const Color(0xFFC0D0C0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? AppColors.primary.withOpacity(0.12)
                : Colors.black.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              isActive: currentTab == NavTab.home,
              color: inactiveColor,
              onTap: () => _onTap(context, NavTab.home),
            ),
            _NavItem(
              icon: Icons.map_rounded,
              isActive: currentTab == NavTab.map,
              color: inactiveColor,
              onTap: () => _onTap(context, NavTab.map),
            ),
            _CartButton(
              count: cartItemCount,
              isActive: currentTab == NavTab.cart,
              onTap: () => _onTap(context, NavTab.cart),
            ),
            _NavItem(
              icon: Icons.receipt_long_rounded,
              isActive: currentTab == NavTab.orders,
              color: inactiveColor,
              onTap: () => _onTap(context, NavTab.orders),
            ),
            _NavItem(
              icon: Icons.person_rounded,
              isActive: currentTab == NavTab.profile,
              color: inactiveColor,
              onTap: () => _onTap(context, NavTab.profile),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 22,
            color: isActive ? AppColors.primary : color,
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 3),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  const _CartButton({
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              color: Colors.white,
              size: 22,
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
