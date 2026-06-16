import 'dart:async';

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
import 'providers/notifications_provider.dart';
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
  String _searchQuery = '';
  late TextEditingController _searchController;
  late ScrollController _scrollController;

  // Flash sale ends in 1h 24m 33s from app start — just a demo countdown.
  late Duration _flashSaleRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _flashSaleRemaining = const Duration(hours: 1, minutes: 24, seconds: 33);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_flashSaleRemaining.inSeconds <= 0) {
        _countdownTimer?.cancel();
        return;
      }
      setState(() {
        _flashSaleRemaining -= const Duration(seconds: 1);
      });
    });
  }

  String get _flashSaleLabel {
    final h = _flashSaleRemaining.inHours;
    final m = _flashSaleRemaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _flashSaleRemaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? 'Ends ${h}h ${m}m ${s}s' : 'Ends ${m}:${s}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  List<RestaurantModel> get _baseList {
    if (_selectedCategory == 'All') {
      return List.from(MockDataService.restaurants);
    }
    return MockDataService.restaurants.where((r) => _matchesCategory(r.category)).toList();
  }

  List<RestaurantModel> _applySearchAndFilter(List<RestaurantModel> list) {
    var result = list;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              r.category.toLowerCase().contains(q) ||
              r.building.toLowerCase().contains(q))
          .toList();
    }

    return _applyFilter(result);
  }

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationsSheet(),
    );
  }

  void _scrollToAllRestaurants() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _showTopRated() {
    setState(() {
      _selectedFilter = 'Rating 4+';
      _selectedCategory = 'All';
    });
    _scrollToAllRestaurants();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final balance = ref.watch(walletBalanceProvider);

    final filteredRestaurants = _applySearchAndFilter(_baseList);

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
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
                            onTap: _showNotifications,
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.push('/profile'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primary,
                              child: Text(
                                MockDataService.currentUser.name[0],
                                style: AppTypography.subheading.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                UniSearchBar(
                  controller: _searchController,
                  onChanged: (q) => setState(() => _searchQuery = q),
                ),
                const SizedBox(height: 12),
                WalletMiniCard(balance: balance),
                const SizedBox(height: 6),
                CategoryChips(
                  selected: _selectedCategory,
                  onSelected: (c) => setState(() => _selectedCategory = c),
                ),
                const SizedBox(height: 8),
                if (_searchQuery.isEmpty) ...[
                  SectionHeader(
                    title: '⚡ Flash Sale',
                    actionText: _flashSaleLabel,
                  ),
                  FlashSaleBanner(
                    onTap: () => context.push('/restaurant/r001'),
                  ),
                  SectionHeader(
                    title: '🔥 Trending Now',
                    actionText: 'See all',
                    onAction: _scrollToAllRestaurants,
                  ),
                ],
              ],
            ),
          ),
          if (_searchQuery.isEmpty) ...[
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
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '⭐ Top Rated',
                actionText: 'See all',
                onAction: _showTopRated,
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
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '📍 Near Me',
                actionText: 'Open map',
                onAction: () => context.go('/tracking'),
              ),
            ),
            const SliverToBoxAdapter(child: CampusMapPreview()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 154,
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
          ],
          SliverToBoxAdapter(
            child: SectionHeader(
              title: _searchQuery.isNotEmpty
                  ? '🔍 Results for "$_searchQuery"'
                  : '🏪 All Restaurants',
              actionText: '${filteredRestaurants.length} places',
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterChips(
              selected: _selectedFilter,
              onSelected: (f) => setState(() => _selectedFilter = f),
            ),
          ),
          filteredRestaurants.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          const Text('🍽️', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 8),
                          Text(
                            'No restaurants found',
                            style: AppTypography.subheading.copyWith(
                              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : SliverList(
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
      '🍔 Food' =>
        category.contains('Food') || category.contains('Asian') || category.contains('Qatari'),
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

// ── Notifications sheet ────────────────────────────────────────────────────

class _NotificationsSheet extends ConsumerWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surfaceColor = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final items = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: AppTypography.heading.copyWith(color: textPrimary),
                  ),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: notifier.clearAll,
                      child: Text(
                        'Clear All',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No new notifications',
                      style: AppTypography.body.copyWith(color: textSecondary),
                    ),
                  ),
                )
              else
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(item.route);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(item.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: AppTypography.subheading.copyWith(
                                      color: textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    style: AppTypography.caption.copyWith(color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16, color: textSecondary),
                              onPressed: () => notifier.dismiss(i),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon button ────────────────────────────────────────────────────────────

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

// ── Filter chips ───────────────────────────────────────────────────────────

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
