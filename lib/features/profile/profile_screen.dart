import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../services/mock_data_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final user = MockDataService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: AppTypography.heading.copyWith(color: textPrimary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(
            name: user.name,
            email: user.email,
            imageUrl: user.avatarUrl,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'Account', color: textSecondary),
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'My Wallet',
            onTap: () => context.push('/wallet'),
          ),
          _MenuTile(
            icon: Icons.location_on_outlined,
            title: 'Saved Locations',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            trailing: Switch(
              value: true,
              onChanged: (_) {},
              activeColor: AppColors.primary,
            ),
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Preferences', color: textSecondary),
          _MenuTile(
            icon: Icons.brightness_6_outlined,
            title: 'Dark Mode',
            trailing: Switch(
              value: isDark,
              onChanged: (_) {},
              activeColor: AppColors.primary,
            ),
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English',
            onTap: () {},
          ),
          const SizedBox(height: 16),
          _SectionTitle(title: 'Support', color: textSecondary),
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.policy_outlined,
            title: 'Terms & Privacy',
            onTap: () {},
          ),
          _MenuTile(
            icon: Icons.logout,
            title: 'Log Out',
            iconColor: AppColors.danger,
            textColor: AppColors.danger,
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Text(
            'Uni Eats v1.0.0',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? imageUrl;
  final Color textPrimary;
  final Color textSecondary;

  const _ProfileHeader({
    required this.name,
    required this.email,
    this.imageUrl,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            backgroundImage: imageUrl != null ? NetworkImage(imageUrl!) : null,
            child: imageUrl == null
                ? const Icon(Icons.person, size: 36, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.subheading.copyWith(color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppTypography.body.copyWith(color: textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Student',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.edit, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color? iconColor;
  final Color? textColor;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primary).withOpacity(0.10),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: textColor ?? Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: defaultSecondary),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.lightTextSecondary),
      contentPadding: EdgeInsets.zero,
    );
  }
}
