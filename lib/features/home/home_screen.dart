import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/restaurant_card.dart';
import '../../core/widgets/restaurant_list_tile.dart';
import '../../core/widgets/search_bar.dart';
import '../../core/widgets/section_header.dart';
import '../../models/restaurant_model.dart';
import '../../services/mock_data_service.dart';
import '../wallet/providers/wallet_provider.dart';
import 'widgets/campus_map_preview.dart';
import 'widgets/category_chips.dart';
import 'widgets/flash_sale_banner.dart';
import 'widgets/wallet_mini_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';
  String _selectedFilter = 'Nearest';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final balance = ref.watch(walletBalanceProvider);

    List<RestaurantModel> filteredRestaurants = _selectedCategory == 'All'
        ? List.from(MockDataService.restaurants)
        : MockDataService.restaurants
            .where((r) => _matchesCategory(r.category))
            .toList();

    filteredRestaurants = _applyFilter(filteredRestaurants);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOOD AFTERNOON',
                            style: AppTypography.label.copyWith(
                              color: mutedColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            '${MockDataService.currentUser.name} 👋',
                            style: AppTypography.displayLarge.copyWith(
                              color: textPrimary,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            'UDST · ${MockDataService.currentUser.roleLabel}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          _IconButton(
                            icon: Icons.notifications_outlined,
                            badge: true,
                            onTap: () {},
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              MockDataService.currentUser.name[0],
                              style: AppTypography.subheading.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const UniSearchBar(),
                const SizedBox(height: 12),
                WalletMiniCard(balance: balance),
                const SizedBox(height: 6),
                CategoryChips(
                  selected: _selectedCategory,
                  onSelected: (c) => setState(() => _selectedCategory = c),
                ),
                const SizedBox(height: 8),
                const SectionHeader(
                  title: '⚡ Flash Sale',
                  actionText: 'Ends 01:24:33',
                ),
                const FlashSaleBanner(),
                const SectionHeader(
                  title: '🔥 Trending Now',
                  actionText: 'See all',
                ),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MockDataService.restaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = MockDataService.restaurants[index];
                  return RestaurantCard(
                    restaurant: restaurant,
                    onTap: () => context.push('/restaurant/${restaurant.id}'),
                    width: 170,
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: '⭐ Top Rated',
              actionText: 'See all',
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final restaurant = MockDataService.restaurants[index];
                return RestaurantListTile(
                  restaurant: restaurant,
                  onTap: () => context.push('/restaurant/${restaurant.id}'),
                );
              },
              childCount: 2,
            ),
          ),
          const SliverToBoxAdapter(
            child: SectionHeader(
              title: '📍 Near Me',
              actionText: 'Open map',
            ),
          ),
          const SliverToBoxAdapter(child: CampusMapPreview()),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: MockDataService.restaurants.length,
                itemBuilder: (context, index) {
                  final restaurant = MockDataService.restaurants[index];
                  return RestaurantCard(
                    restaurant: restaurant,
                    onTap: () => context.push('/restaurant/${restaurant.id}'),
                    width: 120,
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '🏪 All Restaurants',
              actionText: '${filteredRestaurants.length} places',
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterChips(
              selected: _selectedFilter,
              onSelected: (f) => setState(() => _selectedFilter = f),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final restaurant = filteredRestaurants[index];
                return RestaurantListTile(
                  restaurant: restaurant,
                  onTap: () => context.push('/restaurant/${restaurant.id}'),
                );
              },
              childCount: filteredRestaurants.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  bool _matchesCategory(String category) {
    return switch (_selectedCategory) {
      '☕ Coffee' => category.contains('Coffee') || category.contains('Café'),
      '🍔 Food' => category.contains('Food') || category.contains('Asian') || category.contains('Qatari'),
      '🥗 Healthy' => category.contains('Healthy') || category.contains('Açaí'),
      '🍰 Dessert' => category.contains('Bakery') || category.contains('Dessert'),
      '🥤 Drinks' => category.contains('Drinks') || category.contains('Cold'),
      _ => true,
    };
  }

  List<RestaurantModel> _applyFilter(List<RestaurantModel> restaurants) {
    switch (_selectedFilter) {
      case 'Nearest':
        restaurants.sort((a, b) => a.deliveryTimeMin.compareTo(b.deliveryTimeMin));
      case 'Rating 4+':
        return restaurants.where((r) => r.rating >= 4.0).toList();
      case 'Under 10 min':
        return restaurants.where((r) => r.deliveryTimeMin <= 10).toList();
      case 'Pickup Only':
        return restaurants.where((r) => r.offersPickup && !r.offersDelivery).toList();
      case 'Delivery Only':
        return restaurants.where((r) => r.offersDelivery).toList();
    }
    return restaurants;
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final bool badge;
  final VoidCallback onTap;

  const _IconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
          shape: BoxShape.circle,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            if (badge)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  static const filters = [
    'Nearest',
    'Open Now',
    'Rating 4+',
    'Under 10 min',
    'Pickup Only',
    'Delivery Only',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: filters.map((filter) {
          final isSelected = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(filter),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filter,
                  style: AppTypography.caption.copyWith(
                    color: isSelected
                        ? AppColors.primary
                        : isDark
                            ? const Color(0xFF6A8A6A)
                            : AppColors.lightTextSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
