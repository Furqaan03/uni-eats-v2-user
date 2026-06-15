import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order_model.dart';
import '../../../services/mock_data_service.dart';

final ordersProvider = StateNotifierProvider<OrdersNotifier, List<OrderModel>>((ref) {
  return OrdersNotifier();
});

final activeOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => o.isActive).toList();
});

final pastOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => !o.isActive && o.status != OrderStatus.cancelled).toList();
});

final cancelledOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => o.status == OrderStatus.cancelled).toList();
});

class OrdersNotifier extends StateNotifier<List<OrderModel>> {
  OrdersNotifier() : super(MockDataService.orders);

  void addOrder(OrderModel order) {
    state = [order, ...state];
  }

  void rateOrder(String orderId, int rating) {
    state = [
      for (final order in state)
        if (order.id == orderId) order.copyWith(rating: rating) else order,
    ];
  }
}
