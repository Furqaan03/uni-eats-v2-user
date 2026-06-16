import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationItem {
  final String emoji;
  final String title;
  final String subtitle;
  final String route;

  const NotificationItem({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier()
      : super(const [
          NotificationItem(
            emoji: '🎉',
            title: 'Flash Sale Active!',
            subtitle: 'Tim Hortons 30% OFF — ends soon',
            route: '/restaurant/r001',
          ),
          NotificationItem(
            emoji: '✅',
            title: 'Order Delivered',
            subtitle: 'Your Oakberry bowl arrived · 2h ago',
            route: '/orders',
          ),
          NotificationItem(
            emoji: '⭐',
            title: 'Rate Your Last Order',
            subtitle: 'How was the Caribou Coffee experience?',
            route: '/orders',
          ),
          NotificationItem(
            emoji: '💳',
            title: 'Wallet Top-Up',
            subtitle: 'QAR 50.00 added successfully · yesterday',
            route: '/wallet',
          ),
        ]);

  void clearAll() => state = [];

  void dismiss(int index) {
    final updated = List<NotificationItem>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  (ref) => NotificationsNotifier(),
);
