import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/menu_item_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../services/firestore_order_service.dart';
import '../../../services/mock_data_service.dart';

/// Live restaurant catalog — replaces direct MockDataService.restaurants
/// reads, which never reflected anything a vendor actually changed.
final restaurantsProvider = StreamProvider<List<RestaurantModel>>((ref) {
  if (!kUseFirebase) return Stream.value(MockDataService.restaurants);
  return FirestoreOrderService.instance.streamRestaurants();
});

/// Live menu for a single restaurant — replaces direct
/// MockDataService.menuForRestaurant calls.
final menuItemsProvider =
    StreamProvider.family<List<MenuItemModel>, String>((ref, restaurantId) {
  if (!kUseFirebase) {
    return Stream.value(MockDataService.menuForRestaurant(restaurantId));
  }
  return FirestoreOrderService.instance.streamMenuItems(restaurantId);
});

/// One immutable pairing of a menu item with the restaurant it belongs to —
/// needed once items are shown out of their restaurant's own context (e.g.
/// the home screen's "Trending Now" row), where a bare MenuItemModel alone
/// doesn't carry enough to label or link back to its restaurant.
class TrendingMenuItem {
  final MenuItemModel item;
  final RestaurantModel restaurant;
  const TrendingMenuItem({required this.item, required this.restaurant});
}

/// Bestseller/popular items pooled across every restaurant, for the home
/// screen's "Trending Now" row — previously that row showed restaurant
/// cards (duplicating the "All Restaurants" list further down), not items.
final trendingMenuItemsProvider = Provider<List<TrendingMenuItem>>((ref) {
  final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? const [];
  final trending = <TrendingMenuItem>[];
  for (final restaurant in restaurants) {
    final items = ref.watch(menuItemsProvider(restaurant.id)).valueOrNull ?? const [];
    for (final item in items) {
      if (item.isBestseller || item.isPopular) {
        trending.add(TrendingMenuItem(item: item, restaurant: restaurant));
      }
    }
  }
  return trending;
});
