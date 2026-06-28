import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../models/menu_item_model.dart';
import '../../../models/restaurant_model.dart';
import '../../../utils/currency_formatter.dart';

/// Compact card for a single menu item in a horizontal scroller — distinct
/// from the full-width MenuItemCard (core/widgets/menu_item_card.dart), which
/// is built for a vertical list inside a restaurant's own menu, not a
/// horizontal "Trending Now" row spanning multiple restaurants.
class TrendingItemCard extends StatelessWidget {
  final MenuItemModel item;
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final double width;

  const TrendingItemCard({
    super.key,
    required this.item,
    required this.restaurant,
    required this.onTap,
    this.width = 150,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 80,
                  decoration: BoxDecoration(gradient: _gradientForCategory(item.category)),
                  alignment: Alignment.center,
                  child: Icon(_iconForCategory(item.category),
                      color: Colors.white.withOpacity(0.9), size: 28),
                ),
                if (item.isBestseller)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('🔥 BESTSELLER',
                          style: AppTypography.label.copyWith(color: Colors.white, fontSize: 6)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.subheading.copyWith(color: textPrimary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    restaurant.name,
                    style: AppTypography.caption.copyWith(color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    CurrencyFormatter.format(item.effectivePrice),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  LinearGradient _gradientForCategory(String category) {
    if (category.contains('Coffee') || category.contains('Bakery')) {
      return const LinearGradient(colors: [Color(0xFF8B4513), Color(0xFF5C2D0A)]);
    }
    if (category.contains('Healthy') || category.contains('Açaí') || category.contains('Bowls')) {
      return const LinearGradient(colors: [Color(0xFF2D4A1E), Color(0xFF1A3010)]);
    }
    if (category.contains('Drinks') || category.contains('Cold')) {
      return const LinearGradient(colors: [Color(0xFF2E86AB), Color(0xFF1A5276)]);
    }
    if (category.contains('Noodles') || category.contains('Asian')) {
      return const LinearGradient(colors: [Color(0xFFC0392B), Color(0xFF922B21)]);
    }
    return const LinearGradient(colors: [Color(0xFF1A2A3A), Color(0xFF0D1A28)]);
  }

  IconData _iconForCategory(String category) {
    return switch (category) {
      'Coffee' => Icons.coffee,
      'Cold Drinks' => Icons.local_cafe,
      'Bakery' => Icons.bakery_dining,
      'Bowls' => Icons.ramen_dining,
      'Drinks' => Icons.emoji_food_beverage,
      'Food' => Icons.dinner_dining,
      'Noodles' => Icons.ramen_dining,
      'Healthy' => Icons.spa,
      'Mains' => Icons.restaurant,
      _ => Icons.fastfood,
    };
  }
}
