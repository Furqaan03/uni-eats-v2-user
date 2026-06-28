import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/firestore_order_service.dart';

class RestaurantStatus {
  final bool isOpen;
  final bool isBusy;
  // {day3Letter: {isOpen, openMinutes, closeMinutes}}, as saved by the
  // vendor app's opening-hours sheet. Null if the vendor's never saved one.
  final Map<String, dynamic>? openingHours;
  const RestaurantStatus({this.isOpen = true, this.isBusy = false, this.openingHours});

  bool get isOrderable => isOpen && !isBusy;

  static const _dayKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// "8:00 AM – 9:00 PM" for today, or "Closed today" / null if there's no
  /// saved schedule at all.
  String? get todaysHoursLabel {
    if (openingHours == null) return null;
    final todayKey = _dayKeys[DateTime.now().weekday - 1];
    final today = openingHours![todayKey];
    if (today is! Map) return null;
    if (today['isOpen'] != true) return 'Closed today';
    final openMin = (today['openMinutes'] as num?)?.toInt();
    final closeMin = (today['closeMinutes'] as num?)?.toInt();
    if (openMin == null || closeMin == null) return null;
    return '${_formatMinutes(openMin)} – ${_formatMinutes(closeMin)}';
  }

  static String _formatMinutes(int totalMinutes) {
    final h24 = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final period = h24 < 12 ? 'AM' : 'PM';
    final h12 = h24 % 12 == 0 ? 12 : h24 % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $period';
  }
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
      openingHours: data['openingHours'] is Map
          ? Map<String, dynamic>.from(data['openingHours'] as Map)
          : null,
    );
  });
});
