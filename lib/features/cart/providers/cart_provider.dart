import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../models/cart_item_model.dart';
import '../../../models/menu_item_model.dart';
import '../../../models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_persistence_service.dart';

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItemModel>>((ref) {
  final notifier = CartNotifier();
  // Track the signed-in user so a cart never leaks across accounts on a shared
  // device. NOTE: this only resets the IN-MEMORY cart on a user change — it must
  // NOT wipe the disk snapshot, or the force-close resume feature would be
  // destroyed on every launch (the fireImmediately fire looks like a user
  // change). The disk snapshot is scoped by userId instead, so the resume
  // prompt only ever restores it to the same account that saved it.
  String? lastUserId;
  ref.listen<UserModel?>(authProvider, (previous, next) {
    final newId = next?.id ?? '';
    if (newId == lastUserId) return;
    lastUserId = newId;
    notifier.onUserChanged(newId);
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

  // The account that currently owns the cart, used to scope the persisted
  // snapshot so it's never restored to a different user on a shared device.
  String _ownerUserId = '';

  // Fire-and-forget: persistence is a best-effort "resume after force-close"
  // convenience, not a source of truth, so a slow/failed disk write should
  // never block or crash a cart mutation.
  void _persist() {
    if (state.isEmpty) {
      CartPersistenceService.clear();
    } else {
      CartPersistenceService.save(
        userId: _ownerUserId,
        restaurantId: state.first.item.restaurantId,
        cart: state,
      );
    }
  }

  /// Called when the signed-in user changes. Resets the in-memory cart so one
  /// account's items never display under another, but deliberately leaves the
  /// disk snapshot alone — it's scoped by userId and only the matching account
  /// can resume it. Wiping disk here would delete the force-close snapshot on
  /// every launch.
  void onUserChanged(String userId) {
    _ownerUserId = userId;
    if (state.isNotEmpty) state = [];
  }

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
    _persist();
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
    _persist();
  }

  void clear() {
    state = [];
    CartPersistenceService.clear();
  }

  /// Rebuilds the cart from a disk-persisted snapshot, re-resolved against the
  /// CURRENT live menu rather than trusting the saved snapshot's prices —
  /// the whole reason this is a deliberate "Resume your order?" action
  /// instead of a silent restore. Items no longer on the menu, or now
  /// unavailable, are dropped; everything else picks up today's price.
  ///
  /// Returns how many of the originally-saved lines were dropped, so the
  /// caller can tell the user "2 items were no longer available".
  int restoreFrom(List<PendingCartLine> savedLines, List<MenuItemModel> liveMenu) {
    final liveById = {for (final m in liveMenu) m.id: m};
    final restored = <CartItemModel>[];
    var dropped = 0;

    for (final line in savedLines) {
      final live = liveById[line.menuItemId];
      if (live == null || !live.isAvailable) {
        dropped++;
        continue;
      }
      restored.add(CartItemModel(
        id: const Uuid().v4(),
        item: live,
        quantity: line.quantity,
        note: line.note,
      ));
    }

    state = restored;
    _persist();
    return dropped;
  }
}
