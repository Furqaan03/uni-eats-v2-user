import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/theme_provider.dart';
import '../../core/widgets/uni_toast.dart';
import '../../services/mock_data_service.dart';
import '../../utils/currency_formatter.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notifExpanded = false;
  bool _notifOrders = true;
  bool _notifPromos = true;
  bool _notifDriver = true;
  bool _notifLoyalty = false;
  String _language = 'EN';

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
    final user = MockDataService.currentUser;
    final restaurants = MockDataService.restaurants;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            // Profile hero
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primary, width: 3),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                          style: AppTypography.displayMedium.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.edit, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTypography.displayMedium.copyWith(
                            color: textPrimary,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          user.email,
                          style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 10),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.school_outlined, size: 10, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                'UDST Student · CS Dept',
                                style: AppTypography.label.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => UniToast.show(context, 'Profile editing coming soon!'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Edit',
                        style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Student ID card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1C3A1C), const Color(0xFF2A4A2A)]
                      : [const Color(0xFFE8F5E8), const Color(0xFFD0ECD0)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: AppTypography.heading.copyWith(color: Colors.white, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: AppTypography.heading.copyWith(color: textPrimary, fontSize: 11),
                        ),
                        Text(
                          'Student ID: ${user.universityId}',
                          style: AppTypography.caption.copyWith(color: textSecondary, fontSize: 9),
                        ),
                        Text(
                          'Computer Science · Year 3',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Barcode(color: AppColors.primary),
                      const SizedBox(height: 2),
                      Text(
                        user.universityId,
                        style: AppTypography.label.copyWith(color: textMuted, fontSize: 7),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Wallet mini card
            GestureDetector(
              onTap: () => context.push('/wallet'),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Positioned(
                      top: -16,
                      right: -16,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
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
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              CurrencyFormatter.compact(user.walletBalance),
                              style: AppTypography.displayMedium.copyWith(
                                color: Colors.white,
                                fontSize: 22,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '●●●● 4821 · Valid 12/27',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 9,
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
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '+ TOP UP',
                                  style: AppTypography.label.copyWith(color: Colors.white, fontSize: 9),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Stats row
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: cardShadow,
              ),
              child: Row(
                children: [
                  _StatItem(value: '24', label: 'Orders', color: textPrimary),
                  _StatDivider(isDark: isDark),
                  _StatItem(value: '4.8 ★', label: 'Avg Rating', color: AppColors.star),
                  _StatDivider(isDark: isDark),
                  _StatItem(value: 'QR 18', label: 'Avg Spend', color: AppColors.accent),
                  _StatDivider(isDark: isDark),
                  _StatItem(value: 'Gold', label: 'Tier', color: AppColors.primary),
                ],
              ),
            ),

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
                          label: 'Redeem Points',
                          color: AppColors.primary,
                          onTap: () => UniToast.show(context, 'Redeeming points…'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _PillAction(
                          label: 'View Rewards',
                          color: AppColors.star,
                          onTap: () => UniToast.show(context, 'Viewing rewards catalog…'),
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
                        onTap: () => _copyReferralCode(context, user.name),
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
                  _FavItem(
                    emoji: '☕',
                    name: restaurants[0].name,
                    subtitle: '${restaurants[0].building} · ${restaurants[0].rating} ★',
                    status: 'Open',
                    statusColor: AppColors.primary,
                    onTap: () => context.push('/restaurant/${restaurants[0].id}'),
                  ),
                  _Sep(isDark: isDark, inset: true),
                  _FavItem(
                    emoji: '🫐',
                    name: restaurants[1].name,
                    subtitle: '${restaurants[1].building} · ${restaurants[1].rating} ★',
                    status: 'Open',
                    statusColor: AppColors.primary,
                    onTap: () => context.push('/restaurant/${restaurants[1].id}'),
                  ),
                  _Sep(isDark: isDark, inset: true),
                  _FavItem(
                    emoji: '🍕',
                    name: restaurants[2].name,
                    subtitle: '${restaurants[2].building} · ${restaurants[2].rating} ★',
                    status: 'Busy',
                    statusColor: AppColors.accent,
                    onTap: () => context.push('/restaurant/${restaurants[2].id}'),
                  ),
                  GestureDetector(
                    onTap: () => UniToast.show(context, 'Showing all favourites…'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'See all 6 favourites →',
                        textAlign: TextAlign.center,
                        style: AppTypography.label.copyWith(color: AppColors.primary, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                    onTap: () => UniToast.show(context, 'Opening edit profile…'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.credit_card_outlined,
                    iconColor: AppColors.accent,
                    label: 'Wallet & Top-up',
                    value: CurrencyFormatter.format(user.walletBalance),
                    onTap: () => context.push('/wallet'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.location_on_outlined,
                    iconColor: AppColors.primary,
                    label: 'Saved Locations',
                    value: '2 saved',
                    onTap: () => UniToast.show(context, 'Opening saved addresses…'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.layers_outlined,
                    iconColor: AppColors.accent,
                    label: 'Payment Methods',
                    value: 'QPay + Wallet',
                    onTap: () => UniToast.show(context, 'Opening payment methods…'),
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
                  _RowItem(
                    icon: Icons.notifications_outlined,
                    iconColor: AppColors.primary,
                    label: 'Notifications',
                    value: '3 active',
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
                                value: _notifOrders,
                                onChanged: (v) => setState(() => _notifOrders = v),
                              ),
                              _NotifSubRow(
                                label: 'Promotions & Deals',
                                value: _notifPromos,
                                onChanged: (v) => setState(() => _notifPromos = v),
                              ),
                              _NotifSubRow(
                                label: 'Driver Nearby',
                                value: _notifDriver,
                                onChanged: (v) => setState(() => _notifDriver = v),
                              ),
                              _NotifSubRow(
                                label: 'Loyalty & Rewards',
                                value: _notifLoyalty,
                                onChanged: (v) => setState(() => _notifLoyalty = v),
                                last: true,
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
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
                    value: 'B3, Room 204',
                    onTap: () => UniToast.show(context, 'Set default drop-off on campus map…'),
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
                    onTap: () => UniToast.show(context, 'Opening Help & Support…'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.warning_amber_outlined,
                    iconColor: AppColors.danger,
                    label: 'Report a Problem',
                    onTap: () => UniToast.show(context, 'Reporting an issue…'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.info_outline,
                    iconColor: AppColors.primary,
                    label: 'About Uni Eats',
                    value: 'v2.0.0',
                    onTap: () => UniToast.show(context, 'About Uni Eats v2.0.0'),
                  ),
                  _Sep(isDark: isDark, inset: false),
                  _RowItem(
                    icon: Icons.shield_outlined,
                    iconColor: AppColors.primary,
                    label: 'Privacy Policy',
                    onTap: () => UniToast.show(context, 'Opening Privacy Policy…'),
                  ),
                ],
              ),
            ),

            // Logout
            GestureDetector(
              onTap: () => UniToast.show(context, 'Signing out…'),
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
      ),
    );
  }

  String _referralCode(String name) {
    final base = name.split(' ').first.toUpperCase();
    return '${base}100';
  }

  void _copyReferralCode(BuildContext context, String name) {
    UniToast.show(context, 'Code ${_referralCode(name)} copied to clipboard!');
  }
}

class _Barcode extends StatelessWidget {
  final Color color;

  const _Barcode({required this.color});

  @override
  Widget build(BuildContext context) {
    const heights = [18.0, 22.0, 14.0, 20.0, 16.0, 22.0, 12.0, 18.0, 20.0];
    const widths = [1.5, 3.0, 1.5, 2.0, 1.0, 2.5, 1.5, 2.0, 1.0];
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(heights.length, (i) {
          return Container(
            margin: const EdgeInsets.only(left: 1),
            width: widths[i],
            height: heights[i],
            color: color,
          );
        }),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.displayMedium.copyWith(color: color, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label, style: AppTypography.caption.copyWith(color: textMuted, fontSize: 9)),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final bool isDark;

  const _StatDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.grey.withOpacity(0.15),
    );
  }
}

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

  const _FavItem({
    required this.emoji,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.onTap,
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
