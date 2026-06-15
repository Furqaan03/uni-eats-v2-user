import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// Uni Eats v2 entry point.
///
/// TODO: Initialize Firebase before runApp for production builds.
/// TODO: Configure crash reporting without PII logging.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: UniEatsApp(),
    ),
  );
}
