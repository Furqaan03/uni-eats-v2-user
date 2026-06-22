import 'package:flutter/foundation.dart';

@immutable
class MenuItemModel {
  final String id;
  final String restaurantId;
  final String name;
  final String? description;
  final double price;
  final String category;
  final String? imageUrl;
  final bool isAvailable;
  final bool isBestseller;
  final bool isNew;
  final bool isPopular;
  // 0-100 percent discount set by the vendor — null/0 means no discount.
  final double? discountPercent;

  const MenuItemModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    this.description,
    required this.price,
    required this.category,
    this.imageUrl,
    this.isAvailable = true,
    this.isBestseller = false,
    this.isNew = false,
    this.isPopular = false,
    this.discountPercent,
  });

  bool get hasDiscount => discountPercent != null && discountPercent! > 0;
  double get effectivePrice => hasDiscount ? price * (1 - discountPercent! / 100) : price;

  MenuItemModel copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    double? price,
    String? category,
    String? imageUrl,
    bool? isAvailable,
    bool? isBestseller,
    bool? isNew,
    bool? isPopular,
    double? discountPercent,
    bool clearDiscount = false,
  }) {
    return MenuItemModel(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      isBestseller: isBestseller ?? this.isBestseller,
      isNew: isNew ?? this.isNew,
      isPopular: isPopular ?? this.isPopular,
      discountPercent: clearDiscount ? null : (discountPercent ?? this.discountPercent),
    );
  }
}
