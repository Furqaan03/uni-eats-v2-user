import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import 'push_config.dart';

/// Sends FCM push messages directly via the HTTP v1 API, authenticated with a
/// Firebase service account fetched at runtime (see [PushConfig]). All failures
/// are swallowed and logged — a notification never being the reason a user
/// action (placing an order, accepting one) fails.
class SendNotification {
  SendNotification._();

  // Cached OAuth client, reused across sends until its token expires. Minting a
  // token does a network round-trip, so we avoid doing it per message.
  static AccessCredentials? _cachedCredentials;
  static ServiceAccountCredentials? _serviceAccount;

  static Future<ServiceAccountCredentials> _loadServiceAccount() async {
    if (_serviceAccount != null) return _serviceAccount!;
    final raw = await rootBundle.loadString(PushConfig.serviceAccountAssetPath);
    _serviceAccount = ServiceAccountCredentials.fromJson(jsonDecode(raw));
    return _serviceAccount!;
  }

  static Future<String> _accessToken() async {
    final cached = _cachedCredentials;
    if (cached != null && !cached.accessToken.hasExpired) {
      return cached.accessToken.data;
    }
    final account = await _loadServiceAccount();
    final client = await clientViaServiceAccount(account, PushConfig.scopes);
    _cachedCredentials = client.credentials;
    final token = client.credentials.accessToken.data;
    client.close();
    return token;
  }

  /// Push to a single device [token]. [loud] selects the orders channel +
  /// custom sound (for new-order / new-delivery alerts); otherwise the default
  /// channel. [data] is delivered as the FCM data payload for tap routing.
  static Future<void> toToken({
    required String token,
    required String title,
    required String body,
    bool loud = false,
    Map<String, String> data = const {},
  }) async {
    if (!PushConfig.isConfigured) {
      developer.log('[push] skipped — serviceAccountAssetPath not set');
      return;
    }
    if (token.isEmpty) return;

    // Deliberately data-only (no top-level `notification` block): Android
    // only auto-displays `android.notification` overrides when a base
    // `notification` block is also present, so a notification-block message
    // here would either get silently swallowed in the background or shown
    // twice (once by the OS, once by our own onMessage handler). Sending
    // pure data and rendering it ourselves via flutter_local_notifications in
    // both foreground and background keeps display logic in one place.
    final message = {
      'token': token,
      'data': {
        ...data,
        'title': title,
        'body': body,
        'isNewOrder': loud ? 'true' : 'false',
      },
      'android': {'priority': 'high'},
    };

    try {
      final accessToken = await _accessToken();
      final resp = await http.post(
        PushConfig.sendEndpoint,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({'message': message}),
      );
      if (resp.statusCode >= 300) {
        developer.log('[push] send failed ${resp.statusCode}: ${resp.body}');
      } else {
        developer.log('[push] send OK ${resp.statusCode}');
      }
    } catch (e) {
      developer.log('[push] send error', error: e);
    }
  }

  /// Push the same message to many device tokens (e.g. all available drivers).
  /// Sent sequentially; the set is campus-scale small.
  static Future<void> toTokens({
    required Iterable<String> tokens,
    required String title,
    required String body,
    bool loud = false,
    Map<String, String> data = const {},
  }) async {
    for (final t in tokens) {
      await toToken(token: t, title: title, body: body, loud: loud, data: data);
    }
  }
}
