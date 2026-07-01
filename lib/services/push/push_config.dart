/// Configuration for client-side FCM push (see NOTIFICATIONS_PLAN.md).
///
/// Sending uses the FCM HTTP v1 API authenticated by a Firebase service
/// account, bundled as a local git-ignored asset (see [serviceAccountAssetPath]).
class PushConfig {
  PushConfig._();

  /// Firebase project id — target of the FCM v1 `messages:send` endpoint.
  static const String projectId = 'uni-eats-v2-aabf5';

  /// Bundled Firebase service-account JSON used to authenticate FCM v1 sends.
  /// SECURITY: this file is git-ignored (never committed) — it ships in the
  /// local build only. The proper long-term fix is a server holding the key.
  static const String serviceAccountAssetPath = 'assets/push/service_account.json';

  static bool get isConfigured => serviceAccountAssetPath.isNotEmpty;

  /// FCM v1 send endpoint for this project.
  static Uri get sendEndpoint =>
      Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

  /// OAuth scope required to call the FCM v1 API.
  static const List<String> scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  // Android notification channels — must match those created in
  // NotificationService and the `sound` raw resource name.
  static const String ordersChannelId = 'orders_channel';
  static const String defaultChannelId = 'default_channel';
  static const String orderSoundResource = 'order_sound';
}
