import 'dart:developer' as developer;

import '../firestore_order_service.dart';
import 'send_notification.dart';

/// High-level order push events fired by the customer app. Fire-and-forget:
/// callers don't await these — a failed/slow push must never block placing an
/// order.
class OrderPush {
  OrderPush._();

  /// Notify the restaurant that a new order has come in (loud orders channel).
  static Future<void> notifyVendorNewOrder({
    required String vendorId,
    required String orderId,
    required String orderNumber,
    required int itemCount,
    required double total,
  }) async {
    final token = await FirestoreOrderService.instance.fetchVendorFcmToken(vendorId);
    developer.log('[push] notifyVendorNewOrder vendorId=$vendorId token=${token == null ? 'NULL — vendor has no fcmToken saved' : 'present'}');
    if (token == null) return;
    await SendNotification.toToken(
      token: token,
      title: 'New order 🔔',
      body: 'Order $orderNumber — $itemCount item${itemCount == 1 ? '' : 's'}, '
          'Rs ${total.toStringAsFixed(0)}',
      loud: true,
      data: {'orderId': orderId, 'type': 'new_order'},
    );
  }

  /// Notify the restaurant that the customer cancelled their order.
  static Future<void> notifyVendorCancelled({
    required String vendorId,
    required String orderId,
    required String orderNumber,
  }) async {
    final token = await FirestoreOrderService.instance.fetchVendorFcmToken(vendorId);
    if (token == null) return;
    await SendNotification.toToken(
      token: token,
      title: 'Order cancelled',
      body: 'Order $orderNumber was cancelled by the customer.',
      data: {'orderId': orderId, 'type': 'order_cancelled'},
    );
  }
}
