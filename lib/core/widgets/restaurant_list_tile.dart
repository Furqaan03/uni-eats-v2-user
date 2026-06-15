import 'package:flutter/material.dart';

import '../../models/restaurant_model.dart';
import '../../utils/currency_formatter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class RestaurantListTile extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;

  const RestaurantListTile({
    super.key,
    required this.restaurant,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            _buildThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppTypography.subheading.copyWith(
                      color: textPrimary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${restaurant.category} · ⭐ ${restaurant.rating}',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (restaurant.offersDelivery) _Badge(label: 'Delivery'),
                      if (restaurant.offersPickup) _Badge(label: 'Pickup'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${restaurant.deliveryTimeMin} min',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  restaurant.building,
                  style: AppTypography.caption.copyWith(color: mutedColor),
                ),
                if (restaurant.discountPercent != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${restaurant.discountPercent!.toInt()}% OFF',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final gradientColors = _gradientForCategory(restaurant.category);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  List<Color> _gradientForCategory(String category) {
    if (category.contains('Coffee') || category.contains('Bakery')) {
      return [const Color(0xFF8B4513), const Color(0xFF5C2D0A)];
    }
    if (category.contains('Healthy') || category.contains('Açaí')) {
      return [const Color(0xFF2D4A1E), const Color(0xFF1A3010)];
    }
    if (category.contains('Qatari')) {
      return [const Color(0xFF3A2A0A), const Color(0xFF6A4A10)];
    }
    if (category.contains('Asian')) {
      return [const Color(0xFF0A2A1A), const Color(0xFF1A4A2A)];
    }
    return [const Color(0xFF1A2A3A), const Color(0xFF0D1A28)];
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C3A1C) : const Color(0xFFE8F5E8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          color: AppColors.primary,
          fontSize: 7,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
