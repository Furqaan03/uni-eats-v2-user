import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_order_service.dart';

class RestaurantStatus {
  final bool isOpen;
  final bool isBusy;
  const RestaurantStatus({this.isOpen = true, this.isBusy = false});

  bool get isOrderable => isOpen && !isBusy;
}

/// Streams live open/busy status for [restaurantId] from Firestore, set by
/// the vendor app's dashboard toggles. Falls back to open/not-busy if the
/// vendor has never touched the toggles (no doc yet).
final restaurantStatusProvider =
    StreamProvider.family<RestaurantStatus, String>((ref, restaurantId) {
  if (!kUseFirebase) return Stream.value(const RestaurantStatus());
  return FirestoreOrderService.instance.streamRestaurantStatus(restaurantId).map((data) {
    if (data == null) return const RestaurantStatus();
    // An admin suspension overrides the vendor's own open/closed toggle —
    // it must look closed to customers regardless of what the vendor set.
    final adminSuspended = data['adminSuspended'] as bool? ?? false;
    return RestaurantStatus(
      isOpen: adminSuspended ? false : (data['isOpen'] as bool? ?? true),
      isBusy: data['isBusy'] as bool? ?? false,
    );
  });
});
