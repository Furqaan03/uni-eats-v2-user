import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_item_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';

// Set to true after running `flutterfire configure` and adding google-services.json.
// See PLAN.md for full setup instructions.
const kUseFirebase = true;

// Order statuses that mean "this delivery order is currently using up a
// driver's capacity" — mirrors the lifecycle written by the driver/vendor apps.
const _kInFlightDeliveryStatuses = {'ready', 'assigned', 'driverArrived', 'pickedUp', 'enRoute'};

/// Live snapshot of campus delivery capacity, derived from real driver
/// online-status and real in-flight delivery orders — not just "is anyone
/// online" (which doesn't account for drivers already maxed out).
class DeliveryCapacity {
  final int onlineDrivers;
  final int inFlightOrders;

  // Mirrors the driver app's `_kMaxOrders` constant — how many concurrent
  // deliveries one driver can realistically carry.
  static const _maxOrdersPerDriver = 3;

  const DeliveryCapacity({required this.onlineDrivers, required this.inFlightOrders});

  bool get hasAnyDriver => onlineDrivers > 0;
  int get freeSlots => (onlineDrivers * _maxOrdersPerDriver) - inFlightOrders;
  bool get hasCapacity => freeSlots > 0;
}

class FirestoreOrderService {
  FirestoreOrderService._();
  static final FirestoreOrderService instance = FirestoreOrderService._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('orders');

  CollectionReference<Map<String, dynamic>> get _usersCol =>
      FirebaseFirestore.instance.collection('users');

  /// Live delivery-capacity signal — combines online-driver count with
  /// in-flight delivery order count so checkout can gate (or soft-warn on)
  /// the delivery option based on real spare capacity, not just whether
  /// anyone happens to be logged in. Filters status client-side rather than
  /// adding a second `where` clause, to avoid needing another composite
  /// index for what's a small, campus-scale dataset.
  Stream<DeliveryCapacity> streamDeliveryCapacity() {
    late StreamController<DeliveryCapacity> controller;
    int onlineDrivers = 0;
    int inFlightOrders = 0;
    StreamSubscription? driversSub;
    StreamSubscription? ordersSub;

    controller = StreamController<DeliveryCapacity>.broadcast(
      onListen: () {
        driversSub = FirebaseFirestore.instance
            .collection('drivers')
            .where('isOnline', isEqualTo: true)
            .snapshots()
            .listen((snap) {
          onlineDrivers = snap.docs.length;
          controller.add(DeliveryCapacity(onlineDrivers: onlineDrivers, inFlightOrders: inFlightOrders));
        }, onError: (Object e) => controller.addError(e));

        ordersSub = _col.where('orderType', isEqualTo: 'delivery').snapshots().listen((snap) {
          inFlightOrders = snap.docs
              .where((d) => _kInFlightDeliveryStatuses.contains(d.data()['status'] as String?))
              .length;
          controller.add(DeliveryCapacity(onlineDrivers: onlineDrivers, inFlightOrders: inFlightOrders));
        }, onError: (Object e) => controller.addError(e));
      },
      onCancel: () async {
        await driversSub?.cancel();
        await ordersSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Fetch the Firestore profile for an authenticated user, if it exists.
  Future<UserModel?> fetchUserProfile(String uid) async {
    final snap = await _usersCol.doc(uid).get();
    final data = snap.data();
    if (data == null) return null;
    return UserModel(
      id: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      universityId: data['universityId'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (r) => r.name == data['role'],
        orElse: () => UserRole.student,
      ),
      loyaltyPoints: (data['loyaltyPoints'] as num?)?.toInt() ?? 0,
      dietaryPreferences: (data['dietaryPreferences'] as List<dynamic>?)?.cast<String>() ?? const [],
      avatarUrl: data['avatarUrl'] as String?,
      isBlocked: data['isBlocked'] as bool? ?? false,
    );
  }

  /// Create a new user's Firestore profile document (called once at signup).
  Future<void> createUserProfile(UserModel user) async {
    await _usersCol.doc(user.id).set({
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'universityId': user.universityId,
      'role': user.role.name,
      'loyaltyPoints': user.loyaltyPoints,
      'dietaryPreferences': user.dietaryPreferences,
      'avatarUrl': user.avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Persist profile edits (name, phone, dietary preferences, etc.).
  Future<void> updateUserProfile(UserModel user) async {
    await _usersCol.doc(user.id).set({
      'name': user.name,
      'email': user.email,
      'phone': user.phone,
      'universityId': user.universityId,
      'role': user.role.name,
      'loyaltyPoints': user.loyaltyPoints,
      'dietaryPreferences': user.dietaryPreferences,
      'avatarUrl': user.avatarUrl,
    }, SetOptions(merge: true));
  }

  /// Write a new order to Firestore when the user checks out.
  Future<void> placeOrder({
    required String orderId,
    required String orderNumber,
    required String userId,
    required String vendorId,
    required String restaurantName,
    required List<CartItemModel> items,
    required double subtotal,
    required double deliveryFee,
    required double total,
    required DeliveryType deliveryType,
    String customerName = 'Customer',
    DateTime? estimatedDelivery,
    double discount = 0,
  }) async {
    await _col.doc(orderId).set({
      'id': orderId,
      'orderNumber': orderNumber,
      'userId': userId,
      'vendorId': vendorId,
      'driverId': null,
      'driverName': null,
      'customerName': customerName,
      'restaurantName': restaurantName,
      'items': items
          .map((ci) => {
                'itemId': ci.item.id,
                'name': ci.item.name,
                'qty': ci.quantity,
                // Effective (post-discount) price — matches what was charged,
                // so the line item and the order subtotal reconcile exactly.
                'price': ci.item.effectivePrice,
              })
          .toList(),
      'subtotal': subtotal,
      'discount': discount,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': 'placed',
      'paymentStatus': 'held',
      'orderType': deliveryType == DeliveryType.pickup ? 'pickup' : 'delivery',
      'createdAt': FieldValue.serverTimestamp(),
      'estimatedDelivery': estimatedDelivery != null
          ? Timestamp.fromDate(estimatedDelivery)
          : null,
    });
  }

  /// Push a status update for an order (e.g. user-initiated cancellation).
  Future<void> updateOrderStatus(String orderId, String status, {String? cancelReason}) async {
    await _col.doc(orderId).update({
      'status': status,
      if (cancelReason != null) 'cancelReason': cancelReason,
    });
  }

  /// Marks the escrow state of an order's wallet hold — 'held', 'captured', or 'released'.
  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _col.doc(orderId).update({'paymentStatus': paymentStatus});
  }

  /// Fetch the persisted wallet balance for [userId], if any has ever been written.
  Future<double?> fetchWalletBalance(String userId) async {
    final snap = await FirebaseFirestore.instance.collection('wallets').doc(userId).get();
    final data = snap.data();
    return (data?['balance'] as num?)?.toDouble();
  }

  /// Persist the current wallet balance for [userId].
  Future<void> setWalletBalance(String userId, double balance) async {
    await FirebaseFirestore.instance
        .collection('wallets')
        .doc(userId)
        .set({'balance': balance}, SetOptions(merge: true));
  }

  CollectionReference<Map<String, dynamic>> _walletTxCol(String userId) => FirebaseFirestore
      .instance
      .collection('wallets')
      .doc(userId)
      .collection('transactions');

  /// Fetch all persisted wallet transactions for [userId], newest first.
  Future<List<WalletTransactionModel>> fetchWalletTransactions(String userId) async {
    final snap = await _walletTxCol(userId).get();
    final txs = snap.docs.map((d) => WalletTransactionModel.fromMap(d.data())).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return txs;
  }

  /// Persist a single wallet transaction.
  Future<void> addWalletTransaction(String userId, WalletTransactionModel tx) async {
    await _walletTxCol(userId).doc(tx.id).set(tx.toMap());
  }

  /// Real-time stream of menu item availability for a restaurant.
  /// Returns a map of itemId → isAvailable. Missing keys default to available.
  Stream<Map<String, bool>> streamMenuAvailability(String restaurantId) {
    return FirebaseFirestore.instance
        .collection('menuAvailability')
        .doc(restaurantId)
        .snapshots()
        .map((snap) {
          if (!snap.exists || snap.data() == null) return <String, bool>{};
          return snap.data()!.map((k, v) => MapEntry(k, v as bool? ?? true));
        });
  }

  /// Real-time stream of vendor-edited menu item data (price, discount, etc.)
  /// for a restaurant. Returns a map of itemId → raw Firestore fields.
  /// Items the vendor has never edited simply won't have an entry here, so
  /// callers should fall back to the static mock item when a key is missing.
  Stream<Map<String, Map<String, dynamic>>> streamMenuItemOverrides(String restaurantId) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(restaurantId)
        .collection('items')
        .snapshots()
        .map((snap) => {for (final d in snap.docs) d.id: d.data()});
  }

  /// Real-time stream of a restaurant's open/busy status, as set by the
  /// vendor app's dashboard toggles. Missing fields default to open/not-busy.
  Stream<Map<String, dynamic>?> streamRestaurantStatus(String restaurantId) {
    return FirebaseFirestore.instance
        .collection('restaurants')
        .doc(restaurantId)
        .snapshots()
        .map((snap) => snap.data());
  }

  /// Real-time stream of all orders for [userId], newest first.
  /// Sorts client-side to avoid requiring a Firestore composite index.
  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final orders = snap.docs
              .map((d) => _fromFirestore(d.data()))
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return orders;
        });
  }

  static OrderModel _fromFirestore(Map<String, dynamic> d) {
    OrderStatus status;
    switch (d['status'] as String? ?? 'placed') {
      case 'awaitingDriver':
        status = OrderStatus.awaitingDriver;
      case 'preparing':
        status = OrderStatus.preparing;
      case 'ready':
      case 'assigned':
        status = OrderStatus.ready;
      case 'pickedUp':
        status = OrderStatus.pickedUp;
      case 'enRoute':
        status = OrderStatus.delivering;
      case 'arrivedAtCustomer':
        status = OrderStatus.arrived;
      case 'delivered':
        status = OrderStatus.delivered;
      case 'cancelled':
        status = OrderStatus.cancelled;
      default:
        status = OrderStatus.placed;
    }

    // The driver app sets this the instant it's physically at the
    // restaurant — kept as its own field, NOT folded into `status`, because
    // the driver can arrive before the kitchen marks the order ready. Here
    // it's surfaced as the synthetic `driverArrived` status (for the
    // notification/timeline) only while the kitchen is still in
    // preparing/ready — once the order is actually picked up, the real
    // status takes back over.
    final driverAtRestaurant = d['driverAtRestaurant'] as bool? ?? false;
    if (driverAtRestaurant &&
        (status == OrderStatus.preparing || status == OrderStatus.ready)) {
      status = OrderStatus.driverArrived;
    }

    final rawItems = (d['items'] as List<dynamic>? ?? []);
    final items = rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      return CartItemModel(
        id: m['itemId'] as String? ?? '',
        item: MenuItemModel(
          id: m['itemId'] as String? ?? '',
          restaurantId: d['vendorId'] as String? ?? '',
          name: m['name'] as String? ?? '',
          price: (m['price'] as num?)?.toDouble() ?? 0,
          category: '',
        ),
        quantity: (m['qty'] as num?)?.toInt() ?? 1,
      );
    }).toList();

    return OrderModel(
      id: d['id'] as String,
      orderNumber: d['orderNumber'] as String? ?? '#${d['id']}',
      userId: d['userId'] as String? ?? '',
      restaurantId: d['vendorId'] as String? ?? '',
      restaurantName: d['restaurantName'] as String? ?? '',
      items: items,
      subtotal: (d['subtotal'] as num?)?.toDouble() ?? 0,
      deliveryFee: (d['deliveryFee'] as num?)?.toDouble() ?? 0,
      total: (d['total'] as num?)?.toDouble() ?? 0,
      status: status,
      deliveryType: (d['orderType'] as String?) == 'pickup'
          ? DeliveryType.pickup
          : DeliveryType.delivery,
      driverId: d['driverId'] as String?,
      driverName: d['driverName'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      estimatedDelivery: (d['estimatedDelivery'] as Timestamp?)?.toDate(),
      timeline: _buildTimeline(status, (d['orderType'] as String?) == 'pickup'
          ? DeliveryType.pickup
          : DeliveryType.delivery),
      cancelReason: d['cancelReason'] as String?,
      // A missing field means this order predates the escrow feature, when
      // payment was deducted immediately at checkout — treat it as already
      // settled so it's never re-captured (re-deducted) on a later restart.
      paymentStatus: PaymentStatus.values.firstWhere(
        (p) => p.name == (d['paymentStatus'] as String?),
        orElse: () => PaymentStatus.captured,
      ),
    );
  }

  static List<OrderTimelineStep> _buildTimeline(
      OrderStatus status, DeliveryType type) {
    if (type == DeliveryType.pickup) {
      return [
        OrderTimelineStep(
          label: 'Order Placed',
          isComplete: true,
          isCurrent: status == OrderStatus.placed,
          timestamp: DateTime.now(),
        ),
        OrderTimelineStep(
          label: 'Preparing',
          isComplete: status.index >= OrderStatus.preparing.index,
          isCurrent: status == OrderStatus.preparing,
        ),
        OrderTimelineStep(
          label: 'Ready for Pickup',
          isComplete: status == OrderStatus.ready ||
              status == OrderStatus.pickedUp ||
              status == OrderStatus.delivered,
          isCurrent: status == OrderStatus.ready,
        ),
        OrderTimelineStep(
          label: 'Picked Up',
          isComplete: status == OrderStatus.pickedUp ||
              status == OrderStatus.delivered,
          isCurrent: status == OrderStatus.pickedUp ||
              status == OrderStatus.delivered,
        ),
      ];
    } else {
      return [
        OrderTimelineStep(
          label: 'Order Placed',
          isComplete: true,
          isCurrent: status == OrderStatus.placed,
          timestamp: DateTime.now(),
        ),
        OrderTimelineStep(
          label: 'Finding a Driver',
          isComplete: status.index >= OrderStatus.awaitingDriver.index,
          isCurrent: status == OrderStatus.awaitingDriver,
        ),
        OrderTimelineStep(
          label: 'Preparing',
          isComplete: status.index >= OrderStatus.preparing.index,
          isCurrent: status == OrderStatus.preparing,
        ),
        OrderTimelineStep(
          // Driver is at the restaurant but hasn't taken the order yet — this
          // must stay distinct from the actual pickup step below, otherwise
          // the timeline visually claims the order was picked up before the
          // driver ever touched it.
          label: 'Driver Arrived',
          isComplete: status.index >= OrderStatus.driverArrived.index,
          // Covers 'ready' too — food's done and waiting on the driver to
          // physically show up is still "driver arrived" territory from the
          // customer's perspective, and without this the timeline would show
          // no current step at all while status sits on 'ready'.
          isCurrent: status == OrderStatus.ready || status == OrderStatus.driverArrived,
        ),
        OrderTimelineStep(
          // Per the actual delivery flow, "picked up" and "out for delivery"
          // are the same instant — there's no separate driving phase the
          // driver app reports, so this is one step, not two. (A separate
          // 'enRoute' status used to exist for this but was a race hazard —
          // see driver app's advanceDeliveryStep for why it was removed.)
          label: 'Out for Delivery',
          isComplete: status.index >= OrderStatus.pickedUp.index,
          isCurrent: status == OrderStatus.pickedUp || status == OrderStatus.delivering,
        ),
        OrderTimelineStep(
          label: 'Driver Has Arrived',
          isComplete: status.index >= OrderStatus.arrived.index,
          isCurrent: status == OrderStatus.arrived,
        ),
        OrderTimelineStep(
          label: 'Delivered',
          isComplete: status == OrderStatus.delivered,
          isCurrent: status == OrderStatus.delivered,
        ),
      ];
    }
  }
}
