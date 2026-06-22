import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_order_service.dart';

/// Live campus delivery-capacity signal for the checkout screen — drives
/// whether "Delivery" is offered at all, shown with a "may be delayed"
/// warning, or fully available.
final deliveryCapacityProvider = StreamProvider<DeliveryCapacity>((ref) {
  if (!kUseFirebase) {
    return Stream.value(const DeliveryCapacity(onlineDrivers: 1, inFlightOrders: 0));
  }
  return FirestoreOrderService.instance.streamDeliveryCapacity();
});
