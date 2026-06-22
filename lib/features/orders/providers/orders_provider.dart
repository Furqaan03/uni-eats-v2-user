import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/order_model.dart';
import '../../../models/user_model.dart';
import '../../../services/firestore_order_service.dart';
import '../../../services/mock_data_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/notifications_provider.dart';
import '../../wallet/providers/wallet_provider.dart';

final ordersProvider = StateNotifierProvider<OrdersNotifier, List<OrderModel>>((ref) {
  return OrdersNotifier(ref);
});

final activeOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => o.isActive).toList();
});

final pastOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => !o.isActive && o.status != OrderStatus.cancelled).toList();
});

final cancelledOrdersProvider = Provider<List<OrderModel>>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.where((o) => o.status == OrderStatus.cancelled).toList();
});

/// Set this to an order ID to have OrdersScreen auto-open that order's detail sheet.
final pendingOrderDetailProvider = StateProvider<String?>((ref) => null);

class OrdersNotifier extends StateNotifier<List<OrderModel>> {
  OrdersNotifier(this._ref) : super(kUseFirebase ? [] : MockDataService.orders) {
    if (kUseFirebase) {
      // Re-subscribe whenever the authenticated user changes — covers app
      // start (no user yet -> real user), and logout/login as someone else.
      _ref.listen<UserModel?>(authProvider, (previous, next) {
        final newId = next?.id ?? '';
        if (newId == _lastUserId) return;
        _lastUserId = newId;
        _sub?.cancel();
        _localCancelled.clear();
        state = [];
        if (newId.isNotEmpty) _subscribe(newId);
      }, fireImmediately: true);
    }
  }

  final Ref _ref;
  String? _lastUserId;
  StreamSubscription<List<OrderModel>>? _sub;

  /// IDs of orders that were locally cancelled — Firestore must not resurrect them.
  final Set<String> _localCancelled = {};

  void _subscribe(String userId) {
    _sub = FirestoreOrderService.instance
        .streamUserOrders(userId)
        .listen(
          _merge,
          onError: (Object e) => debugPrint('[Orders] Firestore stream error: $e'),
        );
  }

  /// Merge Firestore snapshot with local state.
  /// Rules:
  ///  - Locally cancelled orders are never overwritten by Firestore.
  ///  - If an order already exists locally, prefer whichever has a more
  ///    advanced (higher index) status — prevents old stuck test orders from
  ///    appearing as active when a new order fires the stream.
  ///  - New orders from Firestore (not in local state) are only added if they
  ///    were created in the last 48 hours, filtering out abandoned test data.
  void _merge(List<OrderModel> remote) {
    final localById = {for (final o in state) o.id: o};
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));

    final merged = <OrderModel>[];
    final seen = <String>{};

    for (final remote0 in remote) {
      seen.add(remote0.id);
      if (_localCancelled.contains(remote0.id)) continue; // never resurrect

      final local = localById[remote0.id];
      if (local != null) {
        // Keep whichever status is more advanced (higher enum index = later stage).
        final winner = local.status.index >= remote0.status.index ? local : remote0;
        merged.add(winner);
        _resolveEscrow(previousStatus: local.status, order: winner);
        // Reaching here with a fresh cancellation means the VENDOR rejected it —
        // a local cancelOrder() call would already be in _localCancelled and
        // skipped above before this branch runs.
        if (winner.status == OrderStatus.cancelled && local.status != OrderStatus.cancelled) {
          _ref.read(notificationsProvider.notifier).addNotification(
                NotificationItem(
                  emoji: '😕',
                  title: 'Order Rejected',
                  subtitle: winner.cancelReason != null
                      ? '${winner.restaurantName} rejected your order: ${winner.cancelReason}'
                      : '${winner.restaurantName} was unable to accept your order',
                  route: '/orders',
                ),
              );
        } else if (winner.status != local.status) {
          _pushStatusNotification(winner);
        }
      } else {
        // Unknown order from Firestore — only import if recent.
        if (remote0.createdAt.isAfter(cutoff)) {
          merged.add(remote0);
          // First time seeing this order this session — restore any pending hold.
          if (remote0.status == OrderStatus.placed && remote0.paymentStatus == PaymentStatus.held) {
            _ref.read(walletBalanceProvider.notifier).restoreHold(remote0.id, remote0.total);
          } else {
            _resolveEscrow(previousStatus: OrderStatus.placed, order: remote0);
          }
        }
      }
    }

    // Keep any optimistic local orders not yet confirmed by Firestore.
    for (final local in state) {
      if (!seen.contains(local.id) && !_localCancelled.contains(local.id)) {
        merged.add(local);
      }
    }

    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = merged;
  }

  /// Real, status-driven order notifications — replaces the old fixed
  /// 5s/12s/20s fake timer sequence, which fired on a schedule regardless
  /// of what was actually happening to the order.
  void _pushStatusNotification(OrderModel order) {
    final (emoji, title, subtitle) = switch (order.status) {
      OrderStatus.awaitingDriver =>
        ('🔎', 'Restaurant Confirmed!', '${order.restaurantName} accepted your order — finding you a driver'),
      OrderStatus.preparing => ('🍳', 'Preparing Your Order', '${order.restaurantName} is cooking your food'),
      OrderStatus.driverArrived =>
        ('🛵', 'Driver Arrived at Restaurant', 'Your driver is at ${order.restaurantName} now'),
      OrderStatus.pickedUp =>
        ('📦', 'Picked Up by Driver', 'Your order has left ${order.restaurantName}'),
      OrderStatus.delivering =>
        ('🚗', 'Out for Delivery!', 'Your ${order.restaurantName} order is heading to you'),
      OrderStatus.arrived => ('📍', 'Your Driver Has Arrived!', 'Head out to meet them'),
      OrderStatus.delivered => ('✅', 'Order Delivered!', 'Your ${order.restaurantName} order has arrived. Enjoy!'),
      _ => (null, null, null),
    };
    if (title == null) return;
    _ref.read(notificationsProvider.notifier).addNotification(
          NotificationItem(
            emoji: emoji!,
            title: title,
            subtitle: subtitle!,
            route: order.status == OrderStatus.delivered ? '/orders' : '/tracking',
          ),
        );
  }

  /// Drives the wallet escrow state machine off an order's status change:
  ///  - still 'placed' → nothing to do, hold stays in place.
  ///  - advanced past 'placed' (vendor accepted) → capture the held funds.
  ///  - cancelled while still 'placed' (rejected before acceptance) → release the hold.
  ///  - cancelled after being accepted (already captured) → no wallet action; a
  ///    real refund would need a separate flow, out of scope here.
  void _resolveEscrow({required OrderStatus previousStatus, required OrderModel order}) {
    if (order.status == OrderStatus.cancelled && previousStatus == OrderStatus.placed) {
      _ref.read(walletBalanceProvider.notifier).releaseHold(order.id);
    } else if (order.status != OrderStatus.placed &&
        order.status != OrderStatus.cancelled &&
        order.paymentStatus != PaymentStatus.captured) {
      _ref.read(walletBalanceProvider.notifier).capturePayment(
            order.id,
            order.total,
            description: '${order.restaurantName} — ${order.deliveryType.name}',
          );
      if (kUseFirebase) {
        FirestoreOrderService.instance
            .updatePaymentStatus(order.id, 'captured')
            .catchError((e) => debugPrint('[Firestore] captureMark failed: $e'));
      }
    }
  }

  /// Add a locally-placed order (optimistic update while Firestore syncs).
  void addOrder(OrderModel order) {
    state = [order, ...state];
  }

  /// Update an existing order's status from a Firestore sync.
  void updateOrder(OrderModel updated) {
    if (updated.status == OrderStatus.cancelled) {
      _localCancelled.add(updated.id);
    }
    state = [
      for (final o in state)
        if (o.id == updated.id) updated else o,
    ];
  }

  /// Cancels an order both locally and in Firestore so it doesn't reappear
  /// as active on the next app launch. If the order hadn't been accepted yet,
  /// releases the wallet hold without ever deducting funds.
  void cancelOrder(String orderId, {String? reason}) {
    final order = state.firstWhere((o) => o.id == orderId);
    final wasPlaced = order.status == OrderStatus.placed;
    updateOrder(
      order.copyWith(
        status: OrderStatus.cancelled,
        cancelReason: reason ?? 'Cancelled by customer',
        paymentStatus: wasPlaced ? PaymentStatus.released : order.paymentStatus,
      ),
    );
    if (wasPlaced) {
      _ref.read(walletBalanceProvider.notifier).releaseHold(orderId);
    }
    if (kUseFirebase) {
      FirestoreOrderService.instance
          .updateOrderStatus(orderId, 'cancelled', cancelReason: reason)
          .catchError((e) => debugPrint('[Firestore] cancelOrder failed: $e'));
      if (wasPlaced) {
        FirestoreOrderService.instance
            .updatePaymentStatus(orderId, 'released')
            .catchError((e) => debugPrint('[Firestore] releaseHold failed: $e'));
      }
    }
  }

  void rateOrder(String orderId, int rating) {
    state = [
      for (final order in state)
        if (order.id == orderId) order.copyWith(rating: rating) else order,
    ];
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
