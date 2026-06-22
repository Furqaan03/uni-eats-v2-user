import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_order_service.dart';

/// Streams item availability for [restaurantId] from Firestore.
/// Returns a map of itemId → isAvailable (true = available, false = off).
/// Missing keys mean available (vendor hasn't toggled them yet).
final menuAvailabilityProvider =
    StreamProvider.family<Map<String, bool>, String>((ref, restaurantId) {
  if (!kUseFirebase) return const Stream.empty();
  return FirestoreOrderService.instance.streamMenuAvailability(restaurantId);
});

/// Streams vendor-edited item data (price, discount, etc.) for [restaurantId].
/// Returns a map of itemId → raw Firestore fields. An item with no entry
/// here means the vendor has never edited it — use the static mock data as-is.
final menuItemOverridesProvider =
    StreamProvider.family<Map<String, Map<String, dynamic>>, String>((ref, restaurantId) {
  if (!kUseFirebase) return const Stream.empty();
  return FirestoreOrderService.instance.streamMenuItemOverrides(restaurantId);
});
