import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item_model.dart';
import '../models/menu_item_model.dart';
import '../models/order_model.dart';
import '../models/restaurant_model.dart';
import '../models/user_model.dart';
import '../models/wallet_transaction_model.dart';
import 'mock_data_service.dart';

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

  // Maps a lowercased email or university ID to the uid that owns it, so a
  // wallet transfer can resolve a recipient without querying `users`
  // directly (rules restrict that collection's read to admin/self — see
  // firestore.rules). Holds only a uid pointer, no PII.
  CollectionReference<Map<String, dynamic>> get _directoryCol =>
      FirebaseFirestore.instance.collection('userDirectory');

  CollectionReference<Map<String, dynamic>> get _vouchersCol =>
      FirebaseFirestore.instance.collection('vouchers');

  CollectionReference<Map<String, dynamic>> get _transfersCol =>
      FirebaseFirestore.instance.collection('walletTransfers');

  static String normalizeDirectoryKey(String raw) => raw.trim().toLowerCase();

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
    await _writeDirectoryEntries(user);
  }

  /// Registers this user's email/universityId -> uid pointers so wallet
  /// transfers can resolve a recipient by either. Best-effort: a failure
  /// here shouldn't block signup/profile-save, since the transfer flow
  /// re-checks lookup results before moving any money.
  Future<void> _writeDirectoryEntries(UserModel user) async {
    final batch = FirebaseFirestore.instance.batch();
    if (user.email.isNotEmpty) {
      batch.set(
        _directoryCol.doc(normalizeDirectoryKey(user.email)),
        {'uid': user.id},
      );
    }
    if (user.universityId.isNotEmpty) {
      batch.set(
        _directoryCol.doc(normalizeDirectoryKey(user.universityId)),
        {'uid': user.id},
      );
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('[Firestore] writeDirectoryEntries failed: $e');
    }
  }

  /// Resolves a transfer recipient's uid from the email/student-ID they
  /// typed, via the userDirectory pointer collection. Returns null if no
  /// such account exists.
  Future<String?> lookupUserIdByDirectoryKey(String key) async {
    final snap = await _directoryCol.doc(normalizeDirectoryKey(key)).get();
    return snap.data()?['uid'] as String?;
  }

  /// Fetches a voucher's real terms from Firestore so checkout can validate
  /// a code server-side (the rules layer cross-checks the resulting discount
  /// against this same doc — see firestore.rules `orders` create rule).
  /// Returns null if the code doesn't exist or has been deactivated.
  Future<Map<String, dynamic>?> fetchVoucher(String code) async {
    final snap = await _vouchersCol.doc(code.trim().toUpperCase()).get();
    final data = snap.data();
    if (data == null || data['active'] != true) return null;
    return data;
  }

  /// Sender side of a wallet-to-wallet transfer: debits the sender's own
  /// wallet and opens a pending `walletTransfers` doc in one atomic batch.
  /// The recipient's own client claims it (see [claimIncomingTransfer]) —
  /// this app never writes another user's wallet doc directly, since rules
  /// only allow a user to write their own wallets/{uid} doc.
  Future<void> createOutgoingTransfer({
    required String transferId,
    required String fromUserId,
    required String toUserId,
    required double amount,
    required double newSenderBalance,
    required WalletTransactionModel senderTx,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection('wallets').doc(fromUserId),
      {'balance': newSenderBalance},
      SetOptions(merge: true),
    );
    batch.set(_walletTxCol(fromUserId).doc(senderTx.id), senderTx.toMap());
    batch.set(_transfersCol.doc(transferId), {
      'fromUserId': fromUserId,
      'toUserId': toUserId,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Live stream of transfers addressed to [userId] still awaiting claim.
  Stream<List<Map<String, dynamic>>> streamIncomingPendingTransfers(String userId) {
    return _transfersCol
        .where('toUserId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  /// Recipient side of a transfer: credits their own wallet and marks the
  /// transfer doc completed, atomically.
  Future<void> claimIncomingTransfer({
    required String transferId,
    required String toUserId,
    required double newRecipientBalance,
    required WalletTransactionModel recipientTx,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection('wallets').doc(toUserId),
      {'balance': newRecipientBalance},
      SetOptions(merge: true),
    );
    batch.set(_walletTxCol(toUserId).doc(recipientTx.id), recipientTx.toMap());
    batch.update(_transfersCol.doc(transferId), {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
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
    String? customerPhone,
    DateTime? estimatedDelivery,
    double discount = 0,
    String? voucherCode,
    String? deliveryAddress,
    DateTime? scheduledFor,
  }) async {
    await _col.doc(orderId).set({
      'id': orderId,
      'orderNumber': orderNumber,
      'userId': userId,
      'vendorId': vendorId,
      'driverId': null,
      'driverName': null,
      'customerName': customerName,
      'customerPhone': customerPhone,
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
      if (voucherCode != null) 'voucherCode': voucherCode,
      'deliveryFee': deliveryFee,
      'total': total,
      'status': 'placed',
      'paymentStatus': 'held',
      'orderType': deliveryType == DeliveryType.pickup ? 'pickup' : 'delivery',
      'deliveryAddress': deliveryAddress,
      'createdAt': FieldValue.serverTimestamp(),
      'estimatedDelivery': estimatedDelivery != null
          ? Timestamp.fromDate(estimatedDelivery)
          : null,
      'scheduledFor': scheduledFor != null ? Timestamp.fromDate(scheduledFor) : null,
    });
  }

  /// Push a status update for an order (e.g. user-initiated cancellation).
  Future<void> updateOrderStatus(String orderId, String status, {String? cancelReason}) async {
    await _col.doc(orderId).update({
      'status': status,
      if (cancelReason != null) 'cancelReason': cancelReason,
    });
  }

  /// Customer's own resolution for a stuck "no drivers available" delivery
  /// order — switches it to pickup (they'll collect it themselves) and
  /// clears the flag. Scoped to exactly orderType/deliveryFee/total/
  /// noDriversAvailable per the Firestore rule for this transition; status,
  /// driverId, and userId are deliberately untouched.
  Future<void> switchOrderToPickup(String orderId, {required double newTotal}) async {
    await _col.doc(orderId).update({
      'orderType': 'pickup',
      'deliveryFee': 0,
      'total': newTotal,
      'noDriversAvailable': false,
    });
  }

  /// Marks the escrow state of an order's wallet hold — 'held', 'captured', or 'released'.
  Future<void> updatePaymentStatus(String orderId, String paymentStatus) async {
    await _col.doc(orderId).update({'paymentStatus': paymentStatus});
  }

  /// Writes the customer's rating for a delivered order to `ratings/{orderId}`.
  /// Doc ID == order ID, enforcing one rating per order per the Firestore rule,
  /// which separately verifies vendorId/driverId/userId against the real order.
  Future<void> submitRating({
    required OrderModel order,
    required int vendorRating,
    int? driverRating,
  }) async {
    await FirebaseFirestore.instance.collection('ratings').doc(order.id).set({
      'orderId': order.id,
      'userId': order.userId,
      'vendorId': order.restaurantId,
      'driverId': order.driverId,
      'vendorRating': vendorRating,
      if (driverRating != null) 'driverRating': driverRating,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

  /// Captures an order's escrowed payment as a single atomic write: marks
  /// the order 'captured', sets the new wallet balance, and records the
  /// transaction together. Previously these were three independent
  /// fire-and-forget writes — if the app was force-closed between them
  /// (e.g. balance debited but the order's paymentStatus write hadn't sent
  /// yet), the order would still read as 'held' on next launch and get
  /// captured a second time, debiting the wallet twice and driving the
  /// balance negative. Batching makes it all-or-nothing: either every part
  /// of the capture lands, or none of it does, so a retry on next launch is
  /// always safe.
  Future<void> captureOrderPayment({
    required String orderId,
    required String userId,
    required double newBalance,
    required WalletTransactionModel tx,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_col.doc(orderId), {'paymentStatus': 'captured'});
    batch.set(
      FirebaseFirestore.instance.collection('wallets').doc(userId),
      {'balance': newBalance},
      SetOptions(merge: true),
    );
    batch.set(_walletTxCol(userId).doc(tx.id), tx.toMap());
    await batch.commit();
  }

  /// Same all-or-nothing guarantee as [captureOrderPayment], for wallet-only
  /// operations that don't touch an order doc (top-up, transfer). Without
  /// this, a force-close between the balance write and the transaction
  /// write would leave a balance change with no matching history entry.
  Future<void> updateWalletBalanceWithTransaction({
    required String userId,
    required double newBalance,
    required WalletTransactionModel tx,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.set(
      FirebaseFirestore.instance.collection('wallets').doc(userId),
      {'balance': newBalance},
      SetOptions(merge: true),
    );
    batch.set(_walletTxCol(userId).doc(tx.id), tx.toMap());
    await batch.commit();
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

  /// Live restaurant catalog — merges real vendor-app edits (name, location,
  /// category, description, delivery time, min order, delivery/pickup
  /// support, open/busy) over MockDataService's known per-restaurant
  /// defaults. The defaults still supply rating/reviewCount (no review
  /// system exists yet) and campusX/Y (no map-pin-placement UI exists yet),
  /// and stand in fully for any restaurant whose vendor hasn't edited
  /// anything in Firestore at all — that's why this never reads as "empty"
  /// even before a single vendor has logged in.
  Stream<List<RestaurantModel>> streamRestaurants() {
    return FirebaseFirestore.instance.collection('restaurants').snapshots().map((snap) {
      final liveById = {for (final d in snap.docs) d.id: d.data()};
      return MockDataService.restaurants.map((base) {
        final live = liveById[base.id];
        if (live == null) return base;
        return base.copyWith(
          name: live['name'] as String?,
          building: live['location'] as String?,
          category: live['category'] as String?,
          description: live['description'] as String?,
          deliveryTimeMin: (live['deliveryTimeMin'] as num?)?.toInt(),
          minOrder: (live['minOrder'] as num?)?.toDouble(),
          isOpen: live['isOpen'] as bool?,
          isBusy: live['isBusy'] as bool?,
          offersDelivery: live['offersDelivery'] as bool?,
          offersPickup: live['offersPickup'] as bool?,
        );
      }).toList();
    });
  }

  /// Live menu for [restaurantId] — real items the vendor has added in
  /// Firestore, or the known mock menu as a fallback while a restaurant's
  /// vendor hasn't added any items yet (so Tim Hortons et al. stay usable
  /// for testing without needing every vendor to populate a real menu).
  Stream<List<MenuItemModel>> streamMenuItems(String restaurantId) {
    return FirebaseFirestore.instance
        .collection('menus')
        .doc(restaurantId)
        .collection('items')
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return MockDataService.menuForRestaurant(restaurantId);
          return snap.docs.map((d) {
            final m = d.data();
            final tags = (m['tags'] as List<dynamic>?)?.cast<String>() ?? const [];
            return MenuItemModel(
              id: m['id'] as String? ?? d.id,
              restaurantId: restaurantId,
              name: m['name'] as String? ?? '',
              description: m['description'] as String?,
              price: (m['price'] as num?)?.toDouble() ?? 0,
              category: m['category'] as String? ?? '',
              isAvailable: m['isAvailable'] as bool? ?? true,
              isBestseller: tags.contains('Best Seller'),
              isNew: tags.contains('New'),
              isPopular: tags.contains('Featured') || tags.contains('Top Rated'),
              discountPercent: (m['discountPercent'] as num?)?.toDouble(),
            );
          }).toList();
        });
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
      noDriversAvailable: d['noDriversAvailable'] as bool? ?? false,
      deliveryAddress: d['deliveryAddress'] as String?,
      scheduledFor: (d['scheduledFor'] as Timestamp?)?.toDate(),
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
