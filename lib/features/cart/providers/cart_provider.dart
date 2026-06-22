import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/cart_item_model.dart';
import '../../../models/menu_item_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  final notifier = CartNotifier();
  // Don't let a cart leak across users sharing a device (logout/login).
  String? lastUserId;
  ref.listen<UserModel?>(authProvider, (previous, next) {
    final newId = next?.id ?? '';
    if (newId == lastUserId) return;
    lastUserId = newId;
    notifier.clear();
  }, fireImmediately: true);
  return notifier;
});

final cartTotalProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.total);
});

final cartItemCountProvider = Provider<int>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0, (sum, item) => sum + item.quantity);
});

/// Tracks the most recently viewed restaurant so the Cart screen can offer
/// a way back to add more items, even though `/cart` is a tab route with
/// no Navigator back-stack to pop to.
final lastViewedRestaurantProvider = StateProvider<String?>((ref) => null);

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
