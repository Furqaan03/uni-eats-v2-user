import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/firestore_order_service.dart';
import 'services/push/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kUseFirebase) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Set up FCM receipt + local-notification display. Token is saved per-user
    // once auth resolves (see AuthNotifier._registerPushToken).
    await NotificationService.instance.init();
  }

  runApp(
    const ProviderScope(
      child: UniEatsApp(),
    ),
  );
}
