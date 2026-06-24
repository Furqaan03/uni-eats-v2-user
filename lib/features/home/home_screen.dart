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
import '../../models/order_model.dart';
import '../../services/mock_data_service.dart';
import '../orders/providers/orders_provider.dart';
import '../restaurant/providers/restaurants_provider.dart';
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

  List<RestaurantModel> _baseList(List<RestaurantModel> all) {
    if (_selectedCategory == 'All') return List.from(all);
    return all.where((r) => _matchesCategory(r.category)).toList();
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
    // Mark all as read as soon as the user opens the panel.
    ref.read(notificationsProvider.notifier).markAllRead();
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
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
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? MockDataService.restaurants;

    final filteredRestaurants = _applySearchAndFilter(_baseList(restaurants));

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
                            badge: ref.watch(hasUnreadNotificationsProvider),
                            onTap: _showNotifications,
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () => context.go('/profile'),
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
                _ActiveOrdersBanner(
                  orders: ref.watch(activeOrdersProvider),
                  onOrderTap: (order) {
                    ref.read(pendingOrderDetailProvider.notifier).state = order.id;
                    context.go('/orders');
                  },
                ),
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
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
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
                  final restaurant = restaurants[index];
                  return RestaurantListTile(
                    restaurant: restaurant,
                    onTap: () => context.push('/restaurant/${restaurant.id}'),
                  );
                },
                childCount: restaurants.length < 2 ? restaurants.length : 2,
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
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final restaurant = restaurants[index];
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
        final sorted = List<RestaurantModel>.of(restaurants)
          ..sort((a, b) => a.deliveryTimeMin.compareTo(b.deliveryTimeMin));
        return sorted;
      case 'Rating 4+':
        return restaurants.where((r) => r.rating >= 4.0).toList();
      case 'Under 10 min':
        return restaurants.where((r) => r.deliveryTimeMin <= 10).toList();
      case 'Pickup Only':
        return restaurants.where((r) => r.offersPickup && !r.offersDelivery).toList();
      case 'Delivery Only':
        return restaurants.where((r) => r.offersDelivery && !r.offersPickup).toList();
    }
    return restaurants;
  }
}

// ── Active orders banner ───────────────────────────────────────────────────

class _ActiveOrdersBanner extends StatelessWidget {
  final List<OrderModel> orders;
  final void Function(OrderModel order) onOrderTap;

  const _ActiveOrdersBanner({required this.orders, required this.onOrderTap});

  String _statusLabel(OrderModel o) => switch (o.status) {
        OrderStatus.awaitingDriver => 'Finding a Driver',
        OrderStatus.preparing => 'Preparing',
        OrderStatus.ready => o.deliveryType == DeliveryType.pickup
            ? 'Ready for Pickup'
            : 'Ready',
        OrderStatus.driverArrived => 'Driver At Restaurant',
        OrderStatus.pickedUp => 'Picked Up by Driver',
        OrderStatus.delivering => 'Out for Delivery',
        OrderStatus.arrived => 'Driver Has Arrived',
        _ => 'Order Placed',
      };

  String _statusEmoji(OrderModel o) => switch (o.status) {
        OrderStatus.awaitingDriver => '🔎',
        OrderStatus.preparing => '🍳',
        OrderStatus.ready => '📦',
        OrderStatus.driverArrived => '🛵',
        OrderStatus.pickedUp => '✅',
        OrderStatus.delivering => '🛵',
        OrderStatus.arrived => '📍',
        _ => '🧾',
      };

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🛒 Active Orders',
                style: AppTypography.subheading.copyWith(
                  color: textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${orders.length} order${orders.length > 1 ? 's' : ''}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final isDelivering = order.status == OrderStatus.delivering;
              return GestureDetector(
                onTap: () => onOrderTap(order),
                child: Container(
                  width: 230,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
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
                    children: [
                      // Left accent bar
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDelivering
                                  ? [AppColors.primary, AppColors.primaryDark]
                                  : [AppColors.accent, AppColors.accentDark],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(14),
                              bottomLeft: Radius.circular(14),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.restaurantName,
                                    style: AppTypography.subheading.copyWith(
                                      color: textPrimary,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    order.orderNumber,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _MiniTimeline(order: order, isDark: isDark),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _statusEmoji(order),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _statusLabel(order),
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

// ── Mini timeline for active order cards ──────────────────────────────────

class _MiniTimeline extends StatelessWidget {
  final OrderModel order;
  final bool isDark;

  const _MiniTimeline({required this.order, required this.isDark});

  static const _pickupSteps = [
    OrderStatus.placed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.pickedUp,
  ];

  static const _deliverySteps = [
    OrderStatus.placed,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivering,
    OrderStatus.delivered,
  ];

  static String _label(OrderStatus s, DeliveryType type) => switch (s) {
        OrderStatus.placed => 'Placed',
        OrderStatus.preparing => 'Prep',
        OrderStatus.ready =>
          type == DeliveryType.pickup ? 'Ready' : 'Ready',
        OrderStatus.pickedUp => 'Picked Up',
        OrderStatus.delivering => 'Out',
        OrderStatus.delivered => 'Done',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final steps = order.deliveryType == DeliveryType.pickup
        ? _pickupSteps
        : _deliverySteps;

    // This mini timeline only shows the broad checkpoints — collapse the
    // finer-grained statuses onto the nearest one so the dots don't go
    // blank for a status that isn't itself a checkpoint.
    final checkpointStatus = switch (order.status) {
      OrderStatus.awaitingDriver => OrderStatus.placed,
      OrderStatus.driverArrived => OrderStatus.ready,
      OrderStatus.arrived => OrderStatus.delivering,
      _ => order.status,
    };
    final currentIdx = steps.indexOf(checkpointStatus);

    final doneColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.white24 : Colors.black12;
    final lineHeight = 2.0;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepIdx = (i - 1) ~/ 2;
          final filled = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: lineHeight,
              color: filled ? doneColor : inactiveColor,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final isDone = stepIdx < currentIdx;
        final isCurrent = stepIdx == currentIdx;
        final dotColor = isDone || isCurrent ? doneColor : inactiveColor;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: doneColor.withOpacity(0.3), width: 2)
                    : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _label(steps[stepIdx], order.deliveryType),
              style: TextStyle(
                fontSize: 7,
                fontWeight:
                    isCurrent ? FontWeight.w700 : FontWeight.w400,
                color: isCurrent
                    ? doneColor
                    : isDone
                        ? (isDark ? Colors.white70 : Colors.black54)
                        : inactiveColor,
              ),
            ),
          ],
        );
      }),
    );
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
                  Text('Notifications', style: AppTypography.heading.copyWith(color: textPrimary)),
                  if (items.isNotEmpty)
                    TextButton(
                      onPressed: notifier.clearAll,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
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
                    child: Text('No new notifications',
                        style: AppTypography.body.copyWith(color: textSecondary)),
                  ),
                )
              else
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (item.navType == NotifNavType.go) {
                        context.go(item.route);
                      } else {
                        context.push(item.route);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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
                                  style: AppTypography.subheading
                                      .copyWith(color: textPrimary, fontSize: 13),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: AppTypography.caption.copyWith(color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => notifier.dismiss(i),
                            child: Icon(Icons.close, size: 16, color: textSecondary),
                          ),
                        ],
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
