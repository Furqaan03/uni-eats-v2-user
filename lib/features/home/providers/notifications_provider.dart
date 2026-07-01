import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Shell tab routes use context.go() so the nav bar highlights correctly.
// Non-shell routes (restaurant detail, wallet) use context.push().
enum NotifNavType { go, push }

class NotificationItem {
  final String emoji;
  final String title;
  final String subtitle;
  final String route;
  final NotifNavType navType;
  final bool isRead;

  const NotificationItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.route,
    this.navType = NotifNavType.go,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      emoji: emoji,
      title: title,
      subtitle: subtitle,
      route: route,
      navType: navType,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'emoji': emoji,
        'title': title,
        'subtitle': subtitle,
        'route': route,
        'navType': navType.name,
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        emoji: j['emoji'] as String? ?? '🔔',
        title: j['title'] as String? ?? '',
        subtitle: j['subtitle'] as String? ?? '',
        route: j['route'] as String? ?? '/',
        navType: NotifNavType.values.firstWhere(
          (t) => t.name == j['navType'],
          orElse: () => NotifNavType.go,
        ),
        isRead: j['isRead'] as bool? ?? false,
      );
}

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  // Starts EMPTY and hydrates from disk — no hardcoded seed. A seed here meant
  // a fixed "Flash Sale" entry reappeared on every launch and could never be
  // dismissed for good; real notifications, being in-memory only, were lost on
  // force-close. Now the list is the persisted truth.
  NotificationsNotifier() : super(const []) {
    _load();
  }

  static const _prefsKey = 'customer_notifications_v1';
  // Cap stored history so the list can't grow without bound.
  static const _maxStored = 50;

  bool get hasUnread => state.any((n) => !n.isRead);

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      // Merge anything added before the async load returned, newest first.
      state = [...state, ...list];
    } catch (_) {/* ignore — start empty on any decode error */}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = state.take(_maxStored).toList();
      await prefs.setString(_prefsKey, jsonEncode(trimmed.map((n) => n.toJson()).toList()));
    } catch (_) {/* best-effort */}
  }

  void addNotification(NotificationItem item) {
    state = [item, ...state];
    _persist();
  }

  void markAllRead() {
    if (!hasUnread) return;
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    _persist();
  }

  void clearAll() {
    state = [];
    _persist();
  }

  void dismiss(int index) {
    final updated = List<NotificationItem>.from(state);
    updated.removeAt(index);
    state = updated;
    _persist();
  }

  /// Wipes persisted notifications — call on sign-out so a shared device
  /// doesn't show the previous user's notifications to the next.
  Future<void> clearPersisted() async {
    state = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {/* best-effort */}
  }

  /// Fires once, immediately, at order placement. The rest of the order's
  /// lifecycle (preparing/on the way/delivered) is now notified for real by
  /// OrdersNotifier as it observes actual Firestore status changes — not on
  /// a fixed timer that used to fire regardless of what was really happening.
  void scheduleOrderNotifications(String restaurantName) {
    addNotification(NotificationItem(
      emoji: '🛒',
      title: 'Order Placed!',
      subtitle: 'Your $restaurantName order is confirmed',
      route: '/orders',
    ));
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  (ref) => NotificationsNotifier(),
);

// Derived provider so the badge only rebuilds on unread-state changes.
final hasUnreadNotificationsProvider = Provider<bool>((ref) {
  return ref.watch(notificationsProvider).any((n) => !n.isRead);
});
