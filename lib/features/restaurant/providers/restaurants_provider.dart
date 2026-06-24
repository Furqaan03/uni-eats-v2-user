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
