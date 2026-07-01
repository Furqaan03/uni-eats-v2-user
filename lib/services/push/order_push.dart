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
    final tokens = await FirestoreOrderService.instance.fetchVendorFcmTokens(vendorId);
    if (tokens.isEmpty) return;
    await SendNotification.toTokens(
      tokens: tokens,
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
    final tokens = await FirestoreOrderService.instance.fetchVendorFcmTokens(vendorId);
    if (tokens.isEmpty) return;
    await SendNotification.toTokens(
      tokens: tokens,
      title: 'Order cancelled',
      body: 'Order $orderNumber was cancelled by the customer.',
      data: {'orderId': orderId, 'type': 'order_cancelled'},
    );
  }
}
