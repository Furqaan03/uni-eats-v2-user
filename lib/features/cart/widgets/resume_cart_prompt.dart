import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/widgets/uni_toast.dart';
import '../../../models/restaurant_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../restaurant/providers/restaurants_provider.dart';
import '../providers/cart_persistence_service.dart';
import '../providers/cart_provider.dart';

String _timeAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final h = diff.inMinutes / 60;
  return h < 1.5 ? '1 hour ago' : '${h.round()} hours ago';
}

/// Checks for a force-close-surviving cart and, if found, asks the user
/// whether to resume it rather than restoring it silently — the saved
/// snapshot's prices/availability may be stale by the time the app reopens,
/// so resuming always re-validates against the live menu (see
/// [CartNotifier.restoreFrom]) and tells the user if anything had to drop.
///
/// Safe to call every time the dashboard mounts: it's a no-op once the
/// pending snapshot has been resumed, discarded, or has expired.
Future<void> maybeShowResumeCartPrompt(BuildContext context, WidgetRef ref) async {
  // Don't clobber an already-active cart (e.g. hot-restart in dev, or this
  // somehow fires twice) — resuming only makes sense into an empty cart.
  if (ref.read(cartProvider).isNotEmpty) return;

  // Only resume for a signed-in user, and only their own snapshot — never
  // offer one account's saved cart to whoever opens the app next on a shared
  // device.
  final currentUserId = ref.read(authProvider)?.id;
  if (currentUserId == null || currentUserId.isEmpty) return;

  final snapshot = await CartPersistenceService.loadIfFresh();
  if (snapshot == null) return;
  if (snapshot.userId != currentUserId) return;

  List<RestaurantModel> restaurants;
  try {
    restaurants = await ref.read(restaurantsProvider.future);
  } catch (_) {
    return; // Can't confirm the restaurant still exists — leave the snapshot for next launch.
  }

  RestaurantModel? restaurant;
  for (final r in restaurants) {
    if (r.id == snapshot.restaurantId) {
      restaurant = r;
      break;
    }
  }

  if (restaurant == null) {
    // Restaurant no longer exists at all — nothing to resume.
    await CartPersistenceService.clear();
    return;
  }

  final restaurantName = restaurant.name;
  if (!context.mounted) return;
  final shouldResume = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Resume your order?'),
      content: Text(
        'You have ${snapshot.itemCount} item${snapshot.itemCount == 1 ? '' : 's'} saved from '
        '$restaurantName (${_timeAgo(snapshot.savedAt)}). Prices or availability may have '
        'changed since then.',
        style: AppTypography.body,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Resume Order'),
        ),
      ],
    ),
  );

  if (shouldResume != true) {
    await CartPersistenceService.clear();
    return;
  }

  try {
    final liveMenu = await ref.read(menuItemsProvider(snapshot.restaurantId).future);
    final dropped = ref.read(cartProvider.notifier).restoreFrom(snapshot.lines, liveMenu);
    if (!context.mounted) return;
    if (dropped > 0) {
      UniToast.show(
        context,
        dropped == snapshot.lines.length
            ? 'Those items are no longer available — order discarded.'
            : '$dropped item${dropped == 1 ? '' : 's'} no longer available and were removed.',
      );
    } else {
      UniToast.show(context, 'Order resumed.');
    }
  } catch (_) {
    // Couldn't fetch the live menu (offline, etc.) — leave the snapshot on
    // disk untouched so the prompt can simply try again next launch.
  }
}
