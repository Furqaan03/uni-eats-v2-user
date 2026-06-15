import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/cart_item_model.dart';
import '../../../models/menu_item_model.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  return CartNotifier();
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

class CartNotifier extends StateNotifier<List<CartItemModel>> {
  CartNotifier() : super([]);

  void addItem(MenuItemModel item, {String? note}) {
    final existingIndex = state.indexWhere(
      (cartItem) => cartItem.item.id == item.id && cartItem.note == note,
    );

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(quantity: existing.quantity + 1),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state,
        CartItemModel(id: const Uuid().v4(), item: item, note: note),
      ];
    }
  }

  void removeItem(String cartItemId) {
    final index = state.indexWhere((item) => item.id == cartItemId);
    if (index < 0) return;

    final existing = state[index];
    if (existing.quantity > 1) {
      state = [
        ...state.sublist(0, index),
        existing.copyWith(quantity: existing.quantity - 1),
        ...state.sublist(index + 1),
      ];
    } else {
      state = [
        ...state.sublist(0, index),
        ...state.sublist(index + 1),
      ];
    }
  }

  void clear() => state = [];
}
