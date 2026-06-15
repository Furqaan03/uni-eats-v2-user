import 'package:flutter/foundation.dart';

import 'cart_item_model.dart';

enum OrderStatus {
  placed,
  preparing,
  ready,
  pickedUp,
  delivering,
  delivered,
  cancelled,
}

enum DeliveryType { pickup, delivery }

@immutable
class OrderTimelineStep {
  final String label;
  final DateTime? timestamp;
  final bool isComplete;

  const OrderTimelineStep({
    required this.label,
    this.timestamp,
    this.isComplete = false,
  });
}

@immutable
class OrderModel {
  final String id;
  final String userId;
  final String restaurantId;
  final String restaurantName;
  final List<CartItemModel> items;
  final double subtotal;
  final double deliveryFee;
  final double total;
  final OrderStatus status;
  final DeliveryType deliveryType;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final DateTime createdAt;
  final DateTime? estimatedDelivery;
  final List<OrderTimelineStep> timeline;

  const OrderModel({
    required this.id,
    required this.userId,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    this.status = OrderStatus.placed,
    required this.deliveryType,
    this.driverId,
    this.driverName,
    this.driverPhone,
    required this.createdAt,
    this.estimatedDelivery,
    this.timeline = const [],
  });

  OrderModel copyWith({
    String? id,
    String? userId,
    String? restaurantId,
    String? restaurantName,
    List<CartItemModel>? items,
    double? subtotal,
    double? deliveryFee,
    double? total,
    OrderStatus? status,
    DeliveryType? deliveryType,
    String? driverId,
    String? driverName,
    String? driverPhone,
    DateTime? createdAt,
    DateTime? estimatedDelivery,
    List<OrderTimelineStep>? timeline,
  }) {
    return OrderModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      total: total ?? this.total,
      status: status ?? this.status,
      deliveryType: deliveryType ?? this.deliveryType,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      createdAt: createdAt ?? this.createdAt,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      timeline: timeline ?? this.timeline,
    );
  }

  String get statusLabel {
    return switch (status) {
      OrderStatus.placed => 'Order Placed',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for Pickup',
      OrderStatus.pickedUp => 'Picked Up',
      OrderStatus.delivering => 'On the Way',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;
}
