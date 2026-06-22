import 'package:flutter/foundation.dart';

import 'menu_item_model.dart';

@immutable
class CartItemModel {
  final String id;
  final MenuItemModel item;
  final int quantity;
  final String? note;

  const CartItemModel({
    required this.id,
    required this.item,
    this.quantity = 1,
    this.note,
  });

  CartItemModel copyWith({
    String? id,
    MenuItemModel? item,
    int? quantity,
    String? note,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      item: item ?? this.item,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  double get total => item.effectivePrice * quantity;
}
