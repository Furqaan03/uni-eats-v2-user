import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/cart_item_model.dart';

/// One persisted cart line — just enough to look the live menu item back up
/// on resume. Deliberately does NOT store price/name/etc: those are snapshot
/// data that can go stale (vendor changes a price, pulls an item), so resume
/// always re-fetches the live [MenuItemModel] by id rather than trusting what
/// was on disk.
class PendingCartLine {
  final String menuItemId;
  final int quantity;
  final String? note;

  const PendingCartLine({required this.menuItemId, required this.quantity, this.note});

  Map<String, dynamic> toJson() => {
        'menuItemId': menuItemId,
        'quantity': quantity,
        if (note != null) 'note': note,
      };

  static PendingCartLine fromJson(Map<String, dynamic> json) => PendingCartLine(
        menuItemId: json['menuItemId'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        note: json['note'] as String?,
      );
}

/// A saved-but-not-checked-out cart, restored after a force-close. Carries
/// [savedAt] so the resume prompt can both show "saved 20 min ago" and reject
/// anything older than [CartPersistenceService.maxAge] outright.
class PendingCartSnapshot {
  final String userId;
  final String restaurantId;
  final DateTime savedAt;
  final List<PendingCartLine> lines;

  const PendingCartSnapshot({
    required this.userId,
    required this.restaurantId,
    required this.savedAt,
    required this.lines,
  });

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);
}

/// Persists the cart to disk so it survives a force-close, WITHOUT silently
/// restoring it — callers must explicitly ask the user via a "Resume your
/// order?" prompt, since prices/availability may have moved underneath.
///
/// The snapshot is scoped by [PendingCartSnapshot.userId]: on a shared device
/// a pending order is only ever offered back to the same account that saved it
/// (the resume flow checks ownership before restoring), so it does NOT need to
/// be wiped on every user switch — only on explicit clear (checkout / start
/// new order).
class CartPersistenceService {
  CartPersistenceService._();

  static const _kKey = 'pending_cart_v1';

  /// Anything saved longer ago than this is considered stale — the
  /// restaurant's menu/prices/availability have likely moved on, and
  /// resuming against a multi-hour-old snapshot risks checking out a stale
  /// order. Matches a typical single meal-ordering window.
  static const maxAge = Duration(hours: 2);

  static Future<void> save({
    required String userId,
    required String restaurantId,
    required List<CartItemModel> cart,
  }) async {
    if (cart.isEmpty || userId.isEmpty) {
      // No signed-in owner to scope the cart to — don't persist an
      // unattributable snapshot that could be offered to the wrong account.
      await clear();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'userId': userId,
      'restaurantId': restaurantId,
      'savedAt': DateTime.now().millisecondsSinceEpoch,
      'lines': cart
          .map((c) => PendingCartLine(menuItemId: c.item.id, quantity: c.quantity, note: c.note).toJson())
          .toList(),
    };
    await prefs.setString(_kKey, jsonEncode(payload));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }

  /// Returns the saved snapshot if one exists and is within [maxAge].
  /// A stale snapshot is treated as if it never existed and is wiped here,
  /// so callers never need to separately clean up an expired entry.
  static Future<PendingCartSnapshot?> loadIfFresh() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.fromMillisecondsSinceEpoch(json['savedAt'] as int);
      if (DateTime.now().difference(savedAt) > maxAge) {
        await clear();
        return null;
      }
      final lines = (json['lines'] as List<dynamic>)
          .map((l) => PendingCartLine.fromJson(l as Map<String, dynamic>))
          .toList();
      if (lines.isEmpty) {
        await clear();
        return null;
      }
      return PendingCartSnapshot(
        userId: json['userId'] as String? ?? '',
        restaurantId: json['restaurantId'] as String,
        savedAt: savedAt,
        lines: lines,
      );
    } catch (_) {
      // Corrupt/unreadable entry — discard rather than risk crashing app
      // launch on it forever.
      await clear();
      return null;
    }
  }
}
