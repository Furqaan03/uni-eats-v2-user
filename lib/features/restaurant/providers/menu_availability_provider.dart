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
