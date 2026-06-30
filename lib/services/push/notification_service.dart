import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'push_config.dart';

/// Background isolate handler — must be a top-level function. The system shows
/// the FCM `notification` block itself when the app is backgrounded/killed, so
/// there's nothing to render here; this just keeps the isolate valid.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  developer.log('[push] background message ${message.messageId}');
}

/// Receives FCM messages and renders them as real Android system notifications
/// via flutter_local_notifications. Foreground messages are rendered here;
/// background/killed messages are shown by the OS automatically.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialised = false;

  /// Payload of the message that launched the app from a terminated state, if
  /// any — consumed once the UI is ready (see [takeLaunchPayload]).
  Map<String, dynamic>? _launchPayload;

  /// Set by the app to handle taps (deep-link to an order). Receives the FCM
  /// data payload.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      developer.log('[push] notifications permission denied');
      // Still wire listeners — the user may enable it later in settings.
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(
      const InitializationSettings(android: androidInit),
      onDidReceiveNotificationResponse: (resp) => _handleTapPayload(resp.payload),
    );

    final androidPlugin =
        _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    // Loud channel for new-order/new-delivery alerts, with the custom sound.
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      PushConfig.ordersChannelId,
      'Orders',
      description: 'New order and delivery alerts',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound(PushConfig.orderSoundResource),
    ));
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      PushConfig.defaultChannelId,
      'General',
      description: 'Order updates',
      importance: Importance.high,
      playSound: true,
    ));
    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // App launched from terminated state by tapping a notification.
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data.isNotEmpty) {
      _launchPayload = Map<String, dynamic>.from(initial.data);
    }

    FirebaseMessaging.onMessage.listen((m) {
      if (m.notification != null) _display(m);
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      if (m.data.isNotEmpty) onNotificationTap?.call(Map<String, dynamic>.from(m.data));
    });
  }

  /// Returns and clears the payload of the notification that cold-launched the
  /// app, so the UI can route to the right screen once it's ready.
  Map<String, dynamic>? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  Future<String?> currentToken() => FirebaseMessaging.instance.getToken();

  /// Calls [onChange] whenever FCM rotates the device token so the caller can
  /// persist it.
  void onTokenRefresh(void Function(String token) onChange) {
    FirebaseMessaging.instance.onTokenRefresh.listen(onChange);
  }

  void _handleTapPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) onNotificationTap?.call(Map<String, dynamic>.from(decoded));
    } catch (e) {
      developer.log('[push] bad tap payload', error: e);
    }
  }

  Future<void> _display(RemoteMessage message) async {
    final loud = message.data['isNewOrder'] == 'true';
    final android = AndroidNotificationDetails(
      loud ? PushConfig.ordersChannelId : PushConfig.defaultChannelId,
      loud ? 'Orders' : 'General',
      channelDescription: 'Order notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: loud ? const RawResourceAndroidNotificationSound(PushConfig.orderSoundResource) : null,
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      message.notification?.title,
      message.notification?.body,
      NotificationDetails(android: android),
      payload: jsonEncode(message.data),
    );
  }
}
