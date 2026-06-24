import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/menu_item_card.dart';
import '../../core/widgets/uni_toast.dart';
import '../../models/cart_item_model.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../cart/providers/cart_provider.dart';
import 'providers/menu_availability_provider.dart';
import 'providers/restaurant_status_provider.dart';
import 'providers/restaurants_provider.dart';

class RestaurantDetailScreen extends ConsumerStatefulWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  @override
  ConsumerState<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends ConsumerState<RestaurantDetailScreen> {
  String _selectedCategory = 'All';
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    // Remember this restaurant so the Cart tab can offer a way back to it —
    // `/cart` is a shell tab with no Navigator back-stack to pop to.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(lastViewedRestaurantProvider.notifier).state = widget.restaurantId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    final allRestaurants = ref.watch(restaurantsProvider).valueOrNull ?? MockDataService.restaurants;
    final restaurant = allRestaurants.firstWhere(
      (r) => r.id == widget.restaurantId,
      orElse: () => allRestaurants.first,
    );
    final menuItems = ref.watch(menuItemsProvider(restaurant.id)).valueOrNull ?? const [];
    final menuCategories = <String>{...menuItems.map((m) => m.category)}.toList();
    final chipCategories = ['All', ...menuCategories];
    final sections = _selectedCategory == 'All' ? menuCategories : [_selectedCategory];

    final cart = ref.watch(cartProvider);
    final cartTotal = ref.watch(cartTotalProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final availabilityAsync = ref.watch(menuAvailabilityProvider(restaurant.id));
    final availability = availabilityAsync.valueOrNull ?? {};
    final status = ref.watch(restaurantStatusProvider(restaurant.id)).valueOrNull ??
        RestaurantStatus(isOpen: restaurant.isOpen, isBusy: restaurant.isBusy);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => context.pop(),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _CircleIconButton(
                  icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
                  iconColor: _isFavorite ? AppColors.danger : Colors.white,
                  onTap: () {
                    setState(() => _isFavorite = !_isFavorite);
                    UniToast.show(
                      context,
                      _isFavorite ? 'Added to favourites' : 'Removed from favourites',
                    );
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: _gradientForCategory(restaurant.category),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _heroEmoji(restaurant.category),
                          style: const TextStyle(fontSize: 36),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x59000000), Color(0x00000000), Color(0x8C000000)],
                        stops: [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: !status.isOpen
                            ? AppColors.danger
                            : (status.isBusy ? Colors.orange : AppColors.primary),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        !status.isOpen ? 'CLOSED' : (status.isBusy ? 'BUSY' : 'OPEN NOW'),
                        style: AppTypography.label.copyWith(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 11, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            '${restaurant.deliveryTimeMin}–${restaurant.deliveryTimeMin + 5} min',
                            style: AppTypography.caption.copyWith(color: Colors.white, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 19),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${restaurant.category} · Building ${restaurant.building}',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 11, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                '${restaurant.rating}',
                                style: AppTypography.caption.copyWith(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '(${restaurant.reviewCount})',
                                style: AppTypography.caption.copyWith(color: textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_outlined, size: 11, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          restaurant.building,
                          style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.receipt_long_outlined, size: 11, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Min. ${CurrencyFormatter.format(restaurant.minOrder)}',
                          style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                        ),
                        const Spacer(),
                        Text(
                          restaurant.offersDelivery ? 'Free delivery' : 'Pickup only',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryHeaderDelegate(
              isDark: isDark,
              child: SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: chipCategories.length,
                  itemBuilder: (context, index) {
                    final category = chipCategories[index];
                    final isSelected = category == _selectedCategory;
                    final label = category == 'All'
                        ? 'All'
                        : '${_categoryEmoji(category)} $category';
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedCategory = category),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : isDark
                                    ? AppColors.darkSurface3
                                    : AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(50),
                            boxShadow: isSelected || isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.07),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? Colors.white : textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 6),
              if (!status.isOrderable)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (!status.isOpen ? AppColors.danger : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (!status.isOpen ? AppColors.danger : Colors.orange).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !status.isOpen ? Icons.storefront_outlined : Icons.timer_outlined,
                          size: 18,
                          color: !status.isOpen ? AppColors.danger : Colors.orange,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            !status.isOpen
                                ? 'This restaurant is closed right now — ordering is unavailable.'
                                : 'This restaurant is very busy right now and has paused new orders.',
                            style: AppTypography.caption.copyWith(
                              color: !status.isOpen ? AppColors.danger : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              for (var s = 0; s < sections.length; s++) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Text(
                    '${_categoryEmoji(sections[s])} ${sections[s]}',
                    style: AppTypography.subheading.copyWith(
                      color: textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                for (final item in menuItems.where((m) => m.category == sections[s]))
                  Builder(
                    builder: (context) {
                      final cartItem = cart.cast<CartItemModel?>().firstWhere(
                        (c) => c?.item.id == item.id,
                        orElse: () => null,
                      );
                      final baseAvailable = availability[item.id] ?? item.isAvailable;
                      final canAdd = baseAvailable && status.isOrderable;
                      return MenuItemCard(
                        item: item,
                        quantity: cartItem?.quantity,
                        isAvailable: canAdd,
                        onAdd: canAdd
                            ? () {
                                ref.read(cartProvider.notifier).addItem(item);
                                UniToast.show(context, 'Added ${item.name}');
                              }
                            : null,
                        onRemove: cartItem != null
                            ? () {
                                ref.read(cartProvider.notifier).removeItem(cartItem.id);
                              }
                            : null,
                      );
                    },
                  ),
                if (s < sections.length - 1)
                  Container(
                    height: 1,
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    color: isDark
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.06),
                  ),
              ],
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: cartCount > 0
          ? _StickyCartBar(
              itemCount: cartCount,
              total: cartTotal,
              onTap: () => context.go('/cart'),
            )
          : null,
    );
  }

  LinearGradient _gradientForCategory(String category) {
    if (category.contains('Coffee') || category.contains('Bakery') || category.contains('Café')) {
      return const LinearGradient(
        colors: [Color(0xFF1C3A28), Color(0xFF0A1A10)],
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

  String _heroEmoji(String category) {
    if (category.contains('Coffee') || category.contains('Café')) return '☕';
    if (category.contains('Açaí') || category.contains('Healthy')) return '🥣';
    if (category.contains('Asian')) return '🍜';
    if (category.contains('Qatari')) return '🍲';
    return '🍴';
  }

  String _categoryEmoji(String category) {
    if (category.contains('Coffee')) return '☕';
    if (category.contains('Cold')) return '🧊';
    if (category.contains('Bakery')) return '🧁';
    if (category.contains('Drinks')) return '🥤';
    if (category.contains('Bowls')) return '🥣';
    if (category.contains('Noodles')) return '🍜';
    if (category.contains('Healthy')) return '🥗';
    if (category.contains('Mains')) return '🍛';
    if (category.contains('Food')) return '🍽️';
    return '🍴';
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    this.iconColor = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 16, color: iconColor),
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final bool isDark;
  final Widget child;

  _CategoryHeaderDelegate({required this.isDark, required this.child});

  @override
  double get minExtent => 50;

  @override
  double get maxExtent => 50;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: isDark ? AppColors.darkSurface2 : AppColors.lightBg,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate.isDark != isDark;
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
