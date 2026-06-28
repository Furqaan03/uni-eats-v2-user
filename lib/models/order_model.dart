import 'package:flutter/foundation.dart';

import 'cart_item_model.dart';

enum OrderStatus {
  placed,
  awaitingDriver, // vendor accepted, kitchen waits for a driver to commit
  preparing,
  ready,
  driverArrived, // driver is at the restaurant, not yet picked up
  pickedUp,
  delivering,
  arrived, // driver is at the customer, not yet handed off
  delivered,
  cancelled,
}

enum DeliveryType { pickup, delivery }

/// Tracks the escrow lifecycle of the wallet payment for this order.
/// - held: funds reserved at checkout but not yet deducted
/// - captured: vendor accepted, funds actually deducted
/// - released: order rejected/cancelled before acceptance, hold released without deduction
enum PaymentStatus { held, captured, released }

@immutable
class OrderTimelineStep {
  final String label;
  final DateTime? timestamp;
  final bool isComplete;
  final bool isCurrent;

  const OrderTimelineStep({
    required this.label,
    this.timestamp,
    this.isComplete = false,
    this.isCurrent = false,
  });
}

@immutable
class OrderModel {
  final String id;
  final String orderNumber; // e.g. #P4821, #D3902, #SP1234, #SD5678
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
  final int? rating;
  final String? cancelReason;
  final bool isRefunded;
  final PaymentStatus paymentStatus;
  // True when a driver gave up the delivery (or every online driver
  // declined) and nobody else is free to take over. The order stays
  // 'awaitingDriver' — this is purely a "needs the customer's input" signal
  // surfaced as a banner: pick it up yourself, or cancel.
  final bool noDriversAvailable;
  // Free-text drop-off label the customer picked at checkout, e.g.
  // "Home — Building B3, Room 204". Null for pickup orders.
  final String? deliveryAddress;
  // Set when the customer scheduled this order for a future pickup/delivery
  // time (at least kScheduleLeadTime ahead of placing it) instead of ASAP.
  // Null means a normal, immediate order.
  final DateTime? scheduledFor;

  const OrderModel({
    required this.id,
    required this.orderNumber,
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
    this.rating,
    this.cancelReason,
    this.isRefunded = false,
    this.paymentStatus = PaymentStatus.held,
    this.noDriversAvailable = false,
    this.deliveryAddress,
    this.scheduledFor,
  });

  OrderModel copyWith({
    String? id,
    String? orderNumber,
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
    int? rating,
    String? cancelReason,
    bool? isRefunded,
    PaymentStatus? paymentStatus,
    bool? noDriversAvailable,
    String? deliveryAddress,
    DateTime? scheduledFor,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
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
      rating: rating ?? this.rating,
      cancelReason: cancelReason ?? this.cancelReason,
      isRefunded: isRefunded ?? this.isRefunded,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      noDriversAvailable: noDriversAvailable ?? this.noDriversAvailable,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      scheduledFor: scheduledFor ?? this.scheduledFor,
    );
  }

  String get statusLabel {
    return switch (status) {
      OrderStatus.placed => 'Order Placed',
      OrderStatus.awaitingDriver => 'Finding a Driver',
      OrderStatus.preparing => 'Preparing',
      OrderStatus.ready => 'Ready for Pickup',
      OrderStatus.driverArrived => 'Driver At Restaurant',
      OrderStatus.pickedUp => 'Picked Up by Driver',
      OrderStatus.delivering => 'Out for Delivery',
      OrderStatus.arrived => 'Driver Has Arrived',
      OrderStatus.delivered => 'Delivered',
      OrderStatus.cancelled => 'Cancelled',
    };
  }

  bool get isActive {
    if (status == OrderStatus.delivered || status == OrderStatus.cancelled) {
      return false;
    }
    // For pickup orders, the customer collecting = order complete.
    // For delivery orders, pickedUp = driver collected from restaurant (still in transit).
    if (deliveryType == DeliveryType.pickup && status == OrderStatus.pickedUp) {
      return false;
    }
    return true;
  }
}
