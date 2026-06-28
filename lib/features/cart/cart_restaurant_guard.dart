import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../models/menu_item_model.dart';
import 'providers/cart_provider.dart';

/// A cart can only ever hold items from one restaurant — previously
/// `CartNotifier.addItem` had no such check, so adding from a second
/// restaurant silently mixed both into one order with no way to split it
/// back out. This prompts the user to confirm starting a new cart (which
/// clears whatever was there) whenever the restaurant changes.
///
/// Returns true if the item was added (either no conflict, or the user
/// confirmed clearing the old cart); false if the user backed out.
Future<bool> addToCartWithRestaurantGuard(
  BuildContext context,
  WidgetRef ref,
  MenuItemModel item, {
  String? note,
  String? newRestaurantName,
}) async {
  final cart = ref.read(cartProvider);
  final notifier = ref.read(cartProvider.notifier);
  final currentRestaurantId = cart.isEmpty ? null : cart.first.item.restaurantId;

  if (currentRestaurantId != null && currentRestaurantId != item.restaurantId) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Start a new order?'),
        content: Text(
          'Your cart has items from another restaurant. Adding '
          '${newRestaurantName ?? "this item"} will clear your current cart and '
          'start a new order — you can only order from one restaurant at a time.',
          style: AppTypography.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Start New Order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    notifier.clear();
  }

  notifier.addItem(item, note: note);
  return true;
}
