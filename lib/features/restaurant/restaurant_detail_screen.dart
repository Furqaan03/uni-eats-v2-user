import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/menu_item_card.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/menu_item_model.dart';
import '../../models/restaurant_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../cart/providers/cart_provider.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final restaurant = MockDataService.restaurants.firstWhere(
      (r) => r.id == widget.restaurantId,
      orElse: () => MockDataService.restaurants.first,
    );
    final menuItems = MockDataService.menuForRestaurant(restaurant.id);
    final categories = ['All', ...{...menuItems.map((m) => m.category)}];
    final filtered = _selectedCategory == 'All'
        ? menuItems
        : menuItems.where((m) => m.category == _selectedCategory).toList();

    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: _gradientForCategory(restaurant.category),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          restaurant.name,
                          style: AppTypography.displayMedium.copyWith(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _InfoPill(
                              icon: Icons.star,
                              label: '${restaurant.rating} (${restaurant.reviewCount})',
                            ),
                            const SizedBox(width: 8),
                            _InfoPill(
                              icon: Icons.location_on,
                              label: restaurant.building,
                            ),
                            const SizedBox(width: 8),
                            _InfoPill(
                              icon: Icons.access_time,
                              label: '${restaurant.deliveryTimeMin} min',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    restaurant.description ?? restaurant.category,
                    style: AppTypography.body.copyWith(color: textSecondary),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 34,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = category == _selectedCategory;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedCategory = category),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : isDark
                                      ? AppColors.darkSurface3
                                      : AppColors.lightSurface,
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Text(
                              category,
                              style: AppTypography.caption.copyWith(
                                color: isSelected ? Colors.white : textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = filtered[index];
                final cartItem = cart.cast<dynamic?>().firstWhere(
                  (c) => c!.item.id == item.id,
                  orElse: () => null,
                );
                return MenuItemCard(
                  item: item,
                  quantity: cartItem?.quantity,
                  onAdd: () {
                    ref.read(cartProvider.notifier).addItem(item);
                    UniToast.show(context, 'Added ${item.name}');
                  },
                  onRemove: () {
                    if (cartItem != null) {
                      ref.read(cartProvider.notifier).removeItem(cartItem.id);
                    }
                  },
                );
              },
              childCount: filtered.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      bottomNavigationBar: cartCount > 0
          ? _StickyCartBar(
              itemCount: cartCount,
              total: cartTotal,
              onTap: () => context.push('/cart'),
            )
          : null,
    );
  }

  LinearGradient _gradientForCategory(String category) {
    if (category.contains('Coffee') || category.contains('Bakery')) {
      return const LinearGradient(
        colors: [Color(0xFF8B4513), Color(0xFF5C2D0A)],
      );
    }
    if (category.contains('Healthy') || category.contains('Açaí')) {
      return const LinearGradient(
        colors: [Color(0xFF2D4A1E), Color(0xFF1A3010)],
      );
    }
    if (category.contains('Qatari')) {
      return const LinearGradient(
        colors: [Color(0xFF3A2A0A), Color(0xFF6A4A10)],
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF1A2A3A), Color(0xFF0D1A28)],
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _StickyCartBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final VoidCallback onTap;

  const _StickyCartBar({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View Cart · $itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: AppTypography.button.copyWith(color: Colors.white),
                ),
                Text(
                  CurrencyFormatter.format(total),
                  style: AppTypography.subheading.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
