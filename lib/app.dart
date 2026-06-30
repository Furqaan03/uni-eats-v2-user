import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme.dart';
import 'core/widgets/theme_provider.dart';
import 'router.dart';
import 'services/push/notification_service.dart';

class UniEatsApp extends ConsumerStatefulWidget {
  const UniEatsApp({super.key});

  @override
  ConsumerState<UniEatsApp> createState() => _UniEatsAppState();
}

class _UniEatsAppState extends ConsumerState<UniEatsApp> {
  @override
  void initState() {
    super.initState();
    // Route notification taps to the order. Both a foreground/background tap
    // and a cold-launch tap (consumed once the first frame is up) land here.
    NotificationService.instance.onNotificationTap = _openFromNotification;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final launch = NotificationService.instance.takeLaunchPayload();
      if (launch != null) _openFromNotification(launch);
    });
  }

  void _openFromNotification(Map<String, dynamic> data) {
    // Take the customer to the live tracking screen for the order the
    // notification is about (it resolves the active order itself). Terminal
    // states fall back to the orders list from there.
    ref.read(routerProvider).go('/tracking');
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Uni Eats',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
