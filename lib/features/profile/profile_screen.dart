import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/theme_provider.dart';
import '../../core/widgets/uni_toast.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';
import '../restaurant/providers/restaurants_provider.dart';
import '../wallet/providers/wallet_provider.dart';
import 'providers/preferences_provider.dart';
import 'widgets/location_pin_picker.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifExpanded = false;
  String _language = 'EN';
  File? _avatarFile;

  final Set<String> _dietChips = {'Halal Only', 'Nut-free'};

  static const _allDietChips = [
    ('🥩', 'Halal Only'),
    ('🌱', 'Vegetarian'),
    ('🌿', 'Vegan'),
    ('🥜', 'Nut-free'),
    ('🌾', 'Gluten-free'),
    ('🥛', 'Dairy-free'),
    ('🌶️', 'No Spicy'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final cardShadow = isDark
        ? null
        : [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10)];
    final user = ref.watch(authProvider) ?? MockDataService.currentUser;
    final restaurants = ref.watch(restaurantsProvider).valueOrNull ?? MockDataService.restaurants;
    final walletBalance = ref.watch(walletBalanceProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
        children: [
            // ── Hero card ────────────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Green background — ends cleanly, no bottom padding for wallet
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 52, 20, 56),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Outer ring (white outline like reference)
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.55), width: 3),
                              color: Colors.white.withOpacity(0.15),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: _avatarFile == null
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF80E080), Color(0xFF2E7D32)],
                                      )
                                    : null,
                                image: _avatarFile != null
                                    ? DecorationImage(
                                        image: FileImage(_avatarFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: _avatarFile == null
                                  ? Text(
                                      _initials(user.name),
                                      style: const TextStyle(
                                        color: Color(0xFF1B5E20),
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          // Pencil button
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => _showAvatarPicker(context),
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.edit, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Name
                      Text(
                        user.name,
                        style: AppTypography.displayMedium.copyWith(
                          color: Colors.white,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Student info pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _HeroPill(
                            icon: Icons.email_outlined,
                            label: user.email,
                          ),
                          const SizedBox(width: 8),
                          _HeroPill(
                            icon: Icons.school_outlined,
                            label: 'Computer Science',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Decorative circles
                Positioned(
                  top: 20,
                  right: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  top: 60,
                  left: -30,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Edit button top-right
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _showEditProfile(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Text(
                        'Edit',
                        style: AppTypography.label.copyWith(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
                // Wallet card — straddles green/white boundary
                Positioned(
                  bottom: -52,
                  left: 16,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => context.push('/wallet'),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF00C853), Color(0xFF007A33)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            top: -20,
                            right: -20,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'UNI EATS WALLET',
                                    style: AppTypography.label.copyWith(
                                      color: Colors.white60,
                                      fontSize: 10,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyFormatter.compact(walletBalance),
                                    style: AppTypography.displayMedium.copyWith(
                                      color: Colors.white,
                                      fontSize: 26,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '●●●● 4821 · Valid 12/27',
                                    style: AppTypography.caption.copyWith(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  GestureDetector(
                                    onTap: () => context.push('/wallet'),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '+ TOP UP',
                                        style: AppTypography.label.copyWith(
                                          color: Colors.white,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Icon(Icons.chevron_right, color: Colors.white54, size: 22),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Space for wallet card overlap (bottom half of the card)
            const SizedBox(height: 66),

            // Loyalty & Rewards
            _SectionLabel(text: 'Loyalty & Rewards', color: textMuted),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏆 Gold Member',
                            style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 13),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '2,340 pts · 160 pts to Platinum',
                            style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '2,340',
                            style: AppTypography.displayMedium.copyWith(
                              color: AppColors.star,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            'points',
                            style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: 0.936,
                      minHeight: 6,
                      backgroundColor: isDark ? const Color(0xFF303E30) : const Color(0xFFE0EBE0),
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Silver\n1,000',
                        style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 8),
                      ),
                      Text(
                        'Gold ●\n2,000',
                        textAlign: TextAlign.center,
                        style: AppTypography.label.copyWith(color: AppColors.star, fontSize: 8),
                      ),
                      Text(
                        'Platinum\n2,500',
                        textAlign: TextAlign.right,
                        style: AppTypography.label.copyWith(color: textSecondary, fontSize: 8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PillAction(
                          label: '🎁 Redeem Points',
                          color: AppColors.primary,
                          onTap: () => _showRedeemPoints(context, user.loyaltyPoints),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _PillAction(
                          label: '⭐ View Rewards',
                          color: AppColors.star,
                          onTap: () => _showRewardsCatalog(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Referral
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1A2E1A), const Color(0xFF223022)]
                      : [const Color(0xFFF0FFF0), const Color(0xFFE8F8E8)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🎁 Refer a Friend',
                            style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Earn 100 pts per referral',
                            style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _shareReferralCode(context, user.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Share',
                            style: AppTypography.label.copyWith(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _copyReferralCode(context, user.name),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.4),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Text(
                            _referralCode(user.name),
                            style: AppTypography.subheading.copyWith(
                              color: AppColors.primary,
                              fontSize: 15,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tap to copy →',
                          style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '3 friends joined · 300 pts earned',
                    style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                  ),
                ],
              ),
            ),

            // Favourite Restaurants
            _SectionLabel(text: 'Favourite Restaurants', color: textMuted),
            Builder(builder: (context) {
              final favoriteIds = ref.watch(favoriteRestaurantIdsProvider);
              final favourites =
                  restaurants.where((r) => favoriteIds.contains(r.id)).toList();
              const previewCount = 3;

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: cardShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (favourites.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Tap the ♡ on any restaurant to favourite it',
                          textAlign: TextAlign.center,
                          style: AppTypography.caption.copyWith(color: textMuted, fontSize: 10),
                        ),
                      )
                    else
                      for (var i = 0; i < favourites.length && i < previewCount; i++) ...[
                        if (i > 0) _Sep(isDark: isDark, inset: true),
                        _FavItem(
                          emoji: _favEmoji(favourites[i].category),
                          name: favourites[i].name,
                          subtitle: '${favourites[i].building} · ${favourites[i].rating} ★',
                          status: 'Open',
                          statusColor: AppColors.primary,
                          isFavorite: true,
                          onToggleFavorite: () => ref
                              .read(favoriteRestaurantIdsProvider.notifier)
                              .toggle(favourites[i].id),
                          onTap: () => context.push('/restaurant/${favourites[i].id}'),
                        ),
                      ],
                    if (favourites.length > previewCount)
                      GestureDetector(
                        onTap: () => _showAllFavourites(context, favourites),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'See all ${favourites.length} favourites →',
                            textAlign: TextAlign.center,
                            style:
                                AppTypography.label.copyWith(color: AppColors.primary, fontSize: 9),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            // Dietary Preferences
            _SectionLabel(text: 'Dietary Preferences', color: textMuted),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Used to filter menus and tag items',
                    style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allDietChips.map((chip) {
                      final (emoji, label) = chip;
                      final active = _dietChips.contains(label);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (active) {
                            _dietChips.remove(label);
                          } else {
                            _dietChips.add(label);
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary.withOpacity(isDark ? 0.15 : 0.12)
                                : (isDark ? const Color(0xFF303E30) : const Color(0xFFF0F5F0)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? AppColors.primary
                                  : (isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08)),
                            ),
                          ),
                          child: Text(
                            '$emoji $label',
                            style: AppTypography.label.copyWith(
                              color: active ? AppColors.primary : textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Account section
            _SectionLabel(text: 'Account', color: textMuted),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _RowItem(
                    icon: Icons.person_outline,
                    iconColor: AppColors.primary,
                    label: 'Edit Profile',
                    onTap: () => _showEditProfile(context),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.credit_card_outlined,
                    iconColor: AppColors.accent,
                    label: 'Wallet & Top-up',
                    value: CurrencyFormatter.format(walletBalance),
                    onTap: () => context.push('/wallet'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.location_on_outlined,
                    iconColor: AppColors.primary,
                    label: 'Saved Locations',
                    value: '${ref.watch(savedLocationsProvider).length} saved',
                    onTap: () => _showSavedLocations(context),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.layers_outlined,
                    iconColor: AppColors.accent,
                    label: 'Payment Methods',
                    value: 'QPay + Wallet',
                    onTap: () => _showPaymentMethods(context),
                  ),
                ],
              ),
            ),

            // Preferences section
            _SectionLabel(text: 'Preferences', color: textMuted),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Builder(builder: (context) {
                    final notifPrefs = ref.watch(notificationPrefsProvider);
                    final notifNotifier = ref.read(notificationPrefsProvider.notifier);
                    return Column(
                      children: [
                        _RowItem(
                          icon: Icons.notifications_outlined,
                          iconColor: AppColors.primary,
                          label: 'Notifications',
                          value: '${notifPrefs.activeCount} active',
                          valueColor: AppColors.primary,
                          trailing: AnimatedRotation(
                            turns: _notifExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              size: 18,
                            ),
                          ),
                          onTap: () => setState(() => _notifExpanded = !_notifExpanded),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _notifExpanded
                              ? Column(
                                  children: [
                                    _NotifSubRow(
                                      label: 'Order Updates',
                                      value: notifPrefs.orderUpdates,
                                      onChanged: (v) =>
                                          notifNotifier.update((p) => p.copyWith(orderUpdates: v)),
                                    ),
                                    _NotifSubRow(
                                      label: 'Promotions & Deals',
                                      value: notifPrefs.promotions,
                                      onChanged: (v) =>
                                          notifNotifier.update((p) => p.copyWith(promotions: v)),
                                    ),
                                    _NotifSubRow(
                                      label: 'Driver Nearby',
                                      value: notifPrefs.driverNearby,
                                      onChanged: (v) =>
                                          notifNotifier.update((p) => p.copyWith(driverNearby: v)),
                                    ),
                                    _NotifSubRow(
                                      label: 'Loyalty & Rewards',
                                      value: notifPrefs.loyaltyRewards,
                                      onChanged: (v) =>
                                          notifNotifier.update((p) => p.copyWith(loyaltyRewards: v)),
                                      last: true,
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    );
                  }),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.brightness_6_outlined,
                    iconColor: AppColors.primary,
                    label: 'Dark Mode',
                    trailing: _ToggleSwitch(
                      value: isDark,
                      onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
                    ),
                    onTap: () => ref.read(themeProvider.notifier).toggle(),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.public,
                    iconColor: AppColors.primary,
                    label: 'Language',
                    trailing: _LangPill(
                      value: _language,
                      onChanged: (v) => setState(() => _language = v),
                    ),
                    onTap: null,
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.map_outlined,
                    iconColor: AppColors.accent,
                    label: 'Default Drop-off',
                    value: ref.watch(defaultDropoffProvider).name,
                    onTap: () => _showDropoffPicker(context),
                  ),
                ],
              ),
            ),

            // Support section
            _SectionLabel(text: 'Support', color: textMuted),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _RowItem(
                    icon: Icons.chat_bubble_outline,
                    iconColor: AppColors.accent,
                    label: 'Help & Support',
                    onTap: () => _showHelpSupport(context),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.warning_amber_outlined,
                    iconColor: AppColors.danger,
                    label: 'Report a Problem',
                    onTap: () => _showReportProblem(context),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.info_outline,
                    iconColor: AppColors.primary,
                    label: 'About Uni Eats',
                    value: 'v2.0.0',
                    onTap: () => _showAbout(context),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.primary,
                    label: 'Privacy Policy',
                    onTap: () => _showPrivacyPolicy(context),
                  ),
                ],
              ),
            ),

            // Logout
            GestureDetector(
              onTap: () => _confirmSignOut(context),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, size: 14, color: AppColors.danger),
                    const SizedBox(width: 6),
                    Text(
                      'Sign Out',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked != null && mounted) {
      setState(() => _avatarFile = File(picked.path));
    }
  }

  void _showAvatarPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update Profile Photo',
                style: AppTypography.heading.copyWith(fontSize: 15)),
            const SizedBox(height: 16),
            _AvatarPickerOption(
              icon: Icons.camera_alt_outlined,
              label: 'Take Photo',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
            _AvatarPickerOption(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_avatarFile != null) ...[
              const SizedBox(height: 10),
              _AvatarPickerOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                color: AppColors.danger,
                onTap: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  setState(() => _avatarFile = null);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _favEmoji(String category) {
    final c = category.toLowerCase();
    if (c.contains('coffee') || c.contains('café')) return '☕';
    if (c.contains('dessert') || c.contains('bakery')) return '🍰';
    if (c.contains('healthy') || c.contains('açaí')) return '🥗';
    if (c.contains('drinks') || c.contains('cold')) return '🥤';
    return '🍕';
  }

  void _showAllFavourites(BuildContext context, List<dynamic> favourites) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'All Favourites',
        child: SizedBox(
          height: 360,
          child: ListView.separated(
            itemCount: favourites.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final r = favourites[i];
              return _FavItem(
                emoji: _favEmoji(r.category),
                name: r.name,
                subtitle: '${r.building} · ${r.rating} ★',
                status: 'Open',
                statusColor: AppColors.primary,
                isFavorite: true,
                onToggleFavorite: () =>
                    ref.read(favoriteRestaurantIdsProvider.notifier).toggle(r.id),
                onTap: () {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  context.push('/restaurant/${r.id}');
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _referralCode(String name) {
    final base = name.split(' ').first.toUpperCase();
    return '${base}100';
  }

  String _referralMessage(String code) =>
      '🚨 Hurry — my 100-pt Uni Eats invite code expires soon!\n\n'
      'Use "$code" when you sign up and we BOTH get free campus delivery '
      'credit. Limited spots left this week, grab it now 👇\n\n'
      'Download Uni Eats and enter "$code" at signup.';

  /// "Tap to copy" puts the code on the clipboard (as promised) *and* opens
  /// the share sheet with the full urgency message — previously this only
  /// copied the bare code, with no actual message to send anyone.
  Future<void> _copyReferralCode(BuildContext context, String name) async {
    final code = _referralCode(name);
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    UniToast.show(context, 'Code $code copied — opening share…');
    await Share.share(_referralMessage(code), subject: 'Your Uni Eats invite — code expires soon!');
  }

  Future<void> _shareReferralCode(BuildContext context, String name) async {
    final code = _referralCode(name);
    await Share.share(_referralMessage(code), subject: 'Your Uni Eats invite — code expires soon!');
  }

  // ── Edit Profile ──────────────────────────────────────────────────────────

  void _showEditProfile(BuildContext context) {
    final user = ref.read(authProvider) ?? MockDataService.currentUser;
    final nameCtr = TextEditingController(text: user.name);
    final phoneCtr = TextEditingController(text: user.phone ?? '');

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Edit Profile',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetField(controller: nameCtr, label: 'Full Name', icon: Icons.person_outline),
            const SizedBox(height: 10),
            _SheetField(controller: phoneCtr, label: 'Phone Number', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 20),
            _SheetButton(
              label: 'Save Changes',
              onTap: () {
                final name = nameCtr.text.trim();
                if (name.isEmpty) return;
                ref.read(authProvider.notifier).updateProfile(
                  name: name,
                  phone: phoneCtr.text.trim().isEmpty ? null : phoneCtr.text.trim(),
                );
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Profile updated!');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  void _confirmSignOut(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.logout, size: 32, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Sign Out?', style: AppTypography.heading.copyWith(fontSize: 16)),
              const SizedBox(height: 6),
              Text(
                'You will need to sign in again to place orders.',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text('Cancel', textAlign: TextAlign.center,
                            style: AppTypography.label.copyWith(color: AppColors.primary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).pop();
                        // No manual navigation — the router redirects to
                        // /login automatically once the auth state clears.
                        ref.read(authProvider.notifier).signOut();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Sign Out', textAlign: TextAlign.center,
                            style: AppTypography.label.copyWith(color: Colors.white)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Redeem Points ─────────────────────────────────────────────────────────

  void _showRedeemPoints(BuildContext context, int points) {
    const rewards = [
      ('☕', 'Free Coffee', 200),
      ('🍔', 'Free Burger', 350),
      ('🥗', 'Free Salad', 300),
      ('🎁', 'QR 5 Off', 500),
      ('🚀', 'Free Delivery x3', 400),
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Redeem Points',
        subtitle: 'You have $points pts',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: rewards.map((r) {
            final (emoji, name, cost) = r;
            final canAfford = points >= cost;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: canAfford
                    ? () {
                        Navigator.of(context, rootNavigator: true).pop();
                        UniToast.show(context, '$name redeemed! −$cost pts');
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: canAfford
                        ? AppColors.primary.withOpacity(0.08)
                        : Colors.grey.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canAfford
                          ? AppColors.primary.withOpacity(0.25)
                          : Colors.grey.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(name,
                            style: AppTypography.subheading.copyWith(
                              fontSize: 12,
                              color: canAfford ? null : Colors.grey,
                            )),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: canAfford ? AppColors.primary : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('$cost pts',
                            style: AppTypography.label.copyWith(
                              color: canAfford ? Colors.white : Colors.grey,
                              fontSize: 9,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Rewards Catalog ───────────────────────────────────────────────────────

  void _showRewardsCatalog(BuildContext context) {
    const tiers = [
      ('🥈', 'Silver', '1,000 pts', 'Free delivery on every order'),
      ('🏆', 'Gold', '2,000 pts', '+10% points on every order'),
      ('💎', 'Platinum', '2,500 pts', 'Priority pickup + free item monthly'),
    ];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Rewards Catalog',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: tiers.map((t) {
            final (icon, name, pts, perk) = t;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.star.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.star.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name Tier', style: AppTypography.subheading.copyWith(fontSize: 12)),
                          Text(pts, style: AppTypography.caption.copyWith(color: AppColors.star, fontSize: 9)),
                          const SizedBox(height: 2),
                          Text(perk, style: AppTypography.caption.copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Saved Locations ───────────────────────────────────────────────────────

  void _showSavedLocations(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SavedLocationsSheet(),
    );
  }

  // ── Payment Methods ───────────────────────────────────────────────────────

  void _showPaymentMethods(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Payment Methods',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PayCard(
              label: 'Uni Eats Wallet',
              sub: '●●●● 4821',
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.primary,
              badge: 'DEFAULT',
            ),
            const SizedBox(height: 8),
            _PayCard(
              label: 'QPay',
              sub: 'Linked · ●●●● 9203',
              icon: Icons.credit_card_outlined,
              color: AppColors.accent,
            ),
            const SizedBox(height: 16),
            _SheetButton(
              label: '+ Add Payment Method',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Payment method linking coming soon');
              },
              outlined: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── Default Drop-off ──────────────────────────────────────────────────────

  void _showDropoffPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var selected = ref.read(defaultDropoffProvider);
        return StatefulBuilder(
          builder: (_, setS) => _SheetWrapper(
            title: 'Default Drop-off',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...kDropoffOptions.map((option) {
                  final active = selected.code == option.code;
                  return GestureDetector(
                    onTap: () => setS(() => selected = option),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: active ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active ? AppColors.primary : Colors.grey.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: active ? AppColors.primary : Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(option.name,
                                style: AppTypography.body.copyWith(
                                  fontSize: 12,
                                  color: active ? AppColors.primary : null,
                                )),
                          ),
                          if (active)
                            const Icon(Icons.check_circle, size: 16, color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                _SheetButton(
                  label: 'Save Location',
                  onTap: () {
                    ref.read(defaultDropoffProvider.notifier).setOption(selected);
                    Navigator.pop(ctx);
                    UniToast.show(context, 'Default drop-off set to ${selected.name}');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Help & Support ────────────────────────────────────────────────────────

  void _showHelpSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Help & Support',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SupportOption(
              icon: Icons.chat_bubble_outline,
              color: AppColors.accent,
              title: 'Live Chat',
              sub: 'Avg. reply in 2 min',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Starting live chat…');
              },
            ),
            const SizedBox(height: 8),
            _SupportOption(
              icon: Icons.email_outlined,
              color: AppColors.primary,
              title: 'Email Support',
              sub: 'support@unieats.qa',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Opening email client…');
              },
            ),
            const SizedBox(height: 8),
            _SupportOption(
              icon: Icons.phone_outlined,
              color: AppColors.star,
              title: 'Call Us',
              sub: '+974 4000 0000 · 8am–8pm',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Calling support…');
              },
            ),
            const SizedBox(height: 8),
            _SupportOption(
              icon: Icons.help_outline,
              color: AppColors.primary,
              title: 'FAQ',
              sub: 'Browse common questions',
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                UniToast.show(context, 'Opening FAQ…');
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Report a Problem ──────────────────────────────────────────────────────

  void _showReportProblem(BuildContext context) {
    final ctr = TextEditingController();
    String category = 'Order Issue';

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setS) => _SheetWrapper(
            title: 'Report a Problem',
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category',
                      style: AppTypography.label.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: ['Order Issue', 'Payment', 'App Bug', 'Driver', 'Other'].map((c) {
                      final active = category == c;
                      return GestureDetector(
                        onTap: () => setS(() => category = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: active ? AppColors.primary.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? AppColors.primary : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Text(c,
                              style: AppTypography.label.copyWith(
                                fontSize: 10,
                                color: active ? AppColors.primary : null,
                              )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Description',
                      style: AppTypography.label.copyWith(fontSize: 10)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: ctr,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe the issue…',
                      hintStyle: AppTypography.caption.copyWith(fontSize: 11),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: AppTypography.body.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  _SheetButton(
                    label: 'Submit Report',
                    onTap: () {
                      if (ctr.text.trim().isEmpty) {
                        UniToast.show(context, 'Please describe the problem first');
                        return;
                      }
                      Navigator.pop(ctx);
                      UniToast.show(context, 'Report submitted. We\'ll respond within 24h.');
                    },
                  ),
                ],
              ),
          ),
        );
      },
    );
  }

  // ── About ─────────────────────────────────────────────────────────────────

  void _showAbout(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'About Uni Eats',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text('🍔', style: const TextStyle(fontSize: 36)),
                  const SizedBox(height: 6),
                  Text('Uni Eats', style: AppTypography.heading.copyWith(color: Colors.white, fontSize: 18)),
                  Text('v2.0.0', style: AppTypography.caption.copyWith(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _AboutRow('Campus', 'UDST · Doha, Qatar'),
            _AboutRow('Category', 'Campus Food Delivery'),
            _AboutRow('Support', 'support@unieats.qa'),
            _AboutRow('Built with', 'Flutter + Firebase'),
          ],
        ),
      ),
    );
  }

  // ── Privacy Policy ────────────────────────────────────────────────────────

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetWrapper(
        title: 'Privacy Policy',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacySection('Data We Collect',
                  'We collect your name, email, university ID, order history, and location data to provide campus food delivery services.'),
              _PrivacySection('How We Use It',
                  'Your data is used to process orders, improve recommendations, and send relevant notifications. We never sell your data.'),
              _PrivacySection('Data Retention',
                  'Order history is retained for 12 months. Account data is deleted within 30 days of account closure.'),
              _PrivacySection('Your Rights',
                  'You may request data export or deletion at any time via support@unieats.qa.'),
              _PrivacySection('Security',
                  'All data is encrypted in transit (TLS 1.3) and at rest (AES-256) on Firebase infrastructure.'),
              const SizedBox(height: 8),
              Text('Last updated: June 2025',
                  style: AppTypography.caption.copyWith(fontSize: 9, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── SHEET HELPERS ───────────────────────────────────

class _SheetWrapper extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SheetWrapper({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    // Lift the whole sheet above the keyboard, and let it scroll if the
    // content + keyboard still don't fit — otherwise typing into a field
    // near the bottom of a tall sheet gets hidden behind the keyboard.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 16)),
                      if (subtitle != null)
                        Text(subtitle!,
                            style: AppTypography.caption.copyWith(color: textMuted, fontSize: 10)),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context, rootNavigator: true).pop(),
                    child: Icon(Icons.close_rounded, size: 20, color: textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: AppTypography.body.copyWith(fontSize: 13),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;

  const _SheetButton({required this.label, required this.onTap, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : AppColors.primary,
          borderRadius: BorderRadius.circular(12),
          border: outlined ? Border.all(color: AppColors.primary) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(
            color: outlined ? AppColors.primary : Colors.white,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PayCard extends StatelessWidget {
  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final String? badge;

  const _PayCard({
    required this.label,
    required this.sub,
    required this.icon,
    required this.color,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.subheading.copyWith(fontSize: 12, color: textPrimary)),
                Text(sub, style: AppTypography.caption.copyWith(fontSize: 10, color: textMuted)),
              ],
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: AppTypography.label.copyWith(color: Colors.white, fontSize: 8)),
            ),
        ],
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _SupportOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.subheading.copyWith(fontSize: 12, color: textPrimary)),
                  Text(sub, style: AppTypography.caption.copyWith(fontSize: 10, color: textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: textMuted),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String value;

  const _AboutRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 11)),
          Text(value, style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _PrivacySection extends StatelessWidget {
  final String title;
  final String body;

  const _PrivacySection(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(body, style: AppTypography.body.copyWith(color: textMuted, fontSize: 11)),
        ],
      ),
    );
  }
}

// ─────────────────────── SAVED LOCATIONS SHEET ───────────────────────────────

class _SavedLocationsSheet extends ConsumerWidget {
  const _SavedLocationsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locations = ref.watch(savedLocationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return _SheetWrapper(
      title: 'Saved Locations',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No saved locations yet',
                  style: AppTypography.caption.copyWith(color: textMuted, fontSize: 11)),
            ),
          ...locations.asMap().entries.map((e) {
            final loc = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _addOrEditLocation(context, ref, index: e.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Text(loc.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.label,
                                style:
                                    AppTypography.subheading.copyWith(fontSize: 12, color: textPrimary)),
                            Text(loc.address,
                                style: AppTypography.caption.copyWith(fontSize: 10, color: textMuted)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _addOrEditLocation(context, ref, index: e.key),
                        child: Icon(Icons.edit_outlined, size: 17, color: textMuted),
                      ),
                      const SizedBox(width: 14),
                      GestureDetector(
                        onTap: () {
                          ref.read(savedLocationsProvider.notifier).removeAt(e.key);
                          UniToast.show(context, '${loc.label} removed');
                        },
                        child: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          _SheetButton(
            label: '+ Add Location',
            outlined: true,
            onTap: () => _addOrEditLocation(context, ref),
          ),
        ],
      ),
    );
  }

  /// Opens a small edit form. [index] == null creates a new location;
  /// otherwise edits the existing one at that index.
  void _addOrEditLocation(BuildContext context, WidgetRef ref, {int? index}) {
    final locations = ref.read(savedLocationsProvider);
    final existing = index != null ? locations[index] : null;
    final labelCtr = TextEditingController(text: existing?.label ?? '');
    final addressCtr = TextEditingController(text: existing?.address ?? '');
    var emoji = existing?.emoji ?? '📍';
    double? pinX = existing?.mapX;
    double? pinY = existing?.mapY;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setS) => _SheetWrapper(
          title: index != null ? 'Edit Location' : 'Add Location',
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Icon',
                      style: AppTypography.caption.copyWith(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: kLocationEmojiOptions.map((e) {
                    final active = e == emoji;
                    return GestureDetector(
                      onTap: () => setS(() => emoji = e),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? AppColors.primary : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 16)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _SheetField(
                    controller: labelCtr, label: 'Label (e.g. Home, Office)', icon: Icons.label_outline),
                const SizedBox(height: 10),
                _SheetField(
                    controller: addressCtr,
                    label: 'Address / Building',
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 14),
                LocationPinPicker(
                  initialX: pinX,
                  initialY: pinY,
                  onPinSet: (offset) => setS(() {
                    pinX = offset.dx;
                    pinY = offset.dy;
                  }),
                ),
                const SizedBox(height: 16),
                _SheetButton(
                  label: 'Save Location',
                  onTap: () {
                    final label = labelCtr.text.trim();
                    final address = addressCtr.text.trim();
                    if (label.isEmpty || address.isEmpty) return;
                    final entry =
                        SavedLocation(emoji: emoji, label: label, address: address, mapX: pinX, mapY: pinY);
                    if (index != null) {
                      ref.read(savedLocationsProvider.notifier).updateAt(index, entry);
                    } else {
                      ref.read(savedLocationsProvider.notifier).add(entry);
                    }
                    Navigator.of(sheetCtx, rootNavigator: true).pop();
                    UniToast.show(context, index != null ? 'Location updated' : 'Location added');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── HERO PILL ───────────────────────────────────────

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white70),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── AVATAR PICKER OPTION ────────────────────────────

class _AvatarPickerOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _AvatarPickerOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(width: 12),
            Text(label,
                style: AppTypography.body.copyWith(color: c, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── EXISTING WIDGETS ────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.label.copyWith(color: color, fontSize: 10, letterSpacing: 0.8),
      ),
    );
  }
}

class _PillAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillAction({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.label.copyWith(color: color, fontSize: 9),
        ),
      ),
    );
  }
}

class _FavItem extends StatelessWidget {
  final String emoji;
  final String name;
  final String subtitle;
  final String status;
  final Color statusColor;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const _FavItem({
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 11),
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                  ),
                ],
              ),
            ),
            Text(
              status,
              style: AppTypography.label.copyWith(color: statusColor, fontSize: 9),
            ),
            const SizedBox(width: 4),
            if (onToggleFavorite != null)
              GestureDetector(
                onTap: onToggleFavorite,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    size: 22,
                    color: isFavorite ? AppColors.danger : textSecondary,
                  ),
                ),
              ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 14,
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _RowItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  value!,
                  style: AppTypography.caption.copyWith(
                    color: valueColor ?? textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
          ],
        ),
      ),
    );
  }
}

class _NotifSubRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool last;

  const _NotifSubRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 8, 14, last ? 12 : 8),
      color: isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 11),
            ),
          ),
          _ToggleSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 20,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value
              ? AppColors.primary
              : (isDark ? const Color(0xFF303E30) : const Color(0xFFD8E8D8)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _LangPill extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LangPill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: ['EN', 'AR'].map((lang) {
          final active = value == lang;
          return GestureDetector(
            onTap: () => onChanged(lang),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              color: active ? AppColors.primary : Colors.transparent,
              child: Text(
                lang,
                style: AppTypography.label.copyWith(
                  color: active ? Colors.white : textSecondary,
                  fontSize: 9,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  final bool isDark;
  final bool inset;

  const _Sep({required this.isDark, required this.inset});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: inset ? 14 : 0),
      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
    );
  }
}
