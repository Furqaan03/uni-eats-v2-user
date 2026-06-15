import 'package:flutter/foundation.dart';

@immutable
class RestaurantModel {
  final String id;
  final String name;
  final String category;
  final String building;
  final String? description;
  final double rating;
  final int reviewCount;
  final int deliveryTimeMin;
  final double minOrder;
  final String? imageUrl;
  final bool isOpen;
  final bool offersDelivery;
  final bool offersPickup;
  final double? discountPercent;
  final double campusX;
  final double campusY;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.category,
    required this.building,
    this.description,
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryTimeMin,
    required this.minOrder,
    this.imageUrl,
    this.isOpen = true,
    this.offersDelivery = true,
    this.offersPickup = true,
    this.discountPercent,
    required this.campusX,
    required this.campusY,
  });

  RestaurantModel copyWith({
    String? id,
    String? name,
    String? category,
    String? building,
    String? description,
    double? rating,
    int? reviewCount,
    int? deliveryTimeMin,
    double? minOrder,
    String? imageUrl,
    bool? isOpen,
    bool? offersDelivery,
    bool? offersPickup,
    double? discountPercent,
    double? campusX,
    double? campusY,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      building: building ?? this.building,
      description: description ?? this.description,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      deliveryTimeMin: deliveryTimeMin ?? this.deliveryTimeMin,
      minOrder: minOrder ?? this.minOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      isOpen: isOpen ?? this.isOpen,
      offersDelivery: offersDelivery ?? this.offersDelivery,
      offersPickup: offersPickup ?? this.offersPickup,
      discountPercent: discountPercent ?? this.discountPercent,
      campusX: campusX ?? this.campusX,
      campusY: campusY ?? this.campusY,
    );
  }
}
