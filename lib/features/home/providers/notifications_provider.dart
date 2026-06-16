import 'package:flutter_riverpod/flutter_riverpod.dart';

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
}

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier()
      : super(const [
          NotificationItem(
            emoji: '🎉',
            title: 'Flash Sale Active!',
            subtitle: 'Tim Hortons 30% OFF — ends soon',
            route: '/restaurant/r001',
            navType: NotifNavType.push,
          ),
        ]);

  bool get hasUnread => state.any((n) => !n.isRead);

  void addNotification(NotificationItem item) {
    state = [item, ...state];
  }

  void markAllRead() {
    if (!hasUnread) return;
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void clearAll() => state = [];

  void dismiss(int index) {
    final updated = List<NotificationItem>.from(state);
    updated.removeAt(index);
    state = updated;
  }

  void scheduleOrderNotifications(String restaurantName) {
    addNotification(NotificationItem(
      emoji: '🛒',
      title: 'Order Placed!',
      subtitle: 'Your $restaurantName order is confirmed',
      route: '/orders',
    ));

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      addNotification(NotificationItem(
        emoji: '🍳',
        title: 'Preparing Your Order',
        subtitle: '$restaurantName is cooking your food',
        route: '/orders',
      ));
    });

    Future.delayed(const Duration(seconds: 12), () {
      if (!mounted) return;
      addNotification(NotificationItem(
        emoji: '🚗',
        title: 'Order On the Way!',
        subtitle: 'Your $restaurantName order is heading to you',
        route: '/tracking',
      ));
    });

    Future.delayed(const Duration(seconds: 20), () {
      if (!mounted) return;
      addNotification(NotificationItem(
        emoji: '✅',
        title: 'Order Delivered!',
        subtitle: 'Your $restaurantName order has arrived. Enjoy!',
        route: '/orders',
      ));
      addNotification(NotificationItem(
        emoji: '⭐',
        title: 'Rate Your Order',
        subtitle: 'How was $restaurantName? Tap to leave a review',
        route: '/orders',
      ));
    });
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
