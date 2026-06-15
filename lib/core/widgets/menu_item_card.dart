import 'package:flutter/material.dart';

import '../../models/menu_item_model.dart';
import '../../utils/currency_formatter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class MenuItemCard extends StatelessWidget {
  final MenuItemModel item;
  final int? quantity;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const MenuItemCard({
    super.key,
    required this.item,
    this.quantity,
    this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: _gradientForCategory(item.category),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: _iconForCategory(item.category),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (item.isBestseller)
                      _Tag(label: 'BESTSELLER', color: AppColors.accent),
                    if (item.isNew)
                      _Tag(label: 'NEW', color: AppColors.primary),
                    if (item.isPopular)
                      _Tag(label: 'POPULAR', color: AppColors.star),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.name,
                  style: AppTypography.subheading.copyWith(
                    color: textPrimary,
                    fontSize: 12,
                  ),
                ),
                if (item.description != null)
                  Text(
                    item.description!,
                    style: AppTypography.caption.copyWith(color: textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(item.price),
                  style: AppTypography.subheading.copyWith(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          quantity == null
              ? GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface2 : AppColors.lightSurface2,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: onRemove,
                        child: Icon(Icons.remove, size: 16, color: mutedColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '$quantity',
                          style: AppTypography.subheading.copyWith(
                            color: textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: onAdd,
                        child: const Icon(
                          Icons.add,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  LinearGradient _gradientForCategory(String category) {
    if (category.contains('Coffee')) {
      return const LinearGradient(
        colors: [Color(0xFF6B4226), Color(0xFF3E2616)],
      );
    }
    if (category.contains('Bakery')) {
      return const LinearGradient(
        colors: [Color(0xFFD4A373), Color(0xFFA97142)],
      );
    }
    if (category.contains('Healthy') || category.contains('Bowls')) {
      return const LinearGradient(
        colors: [Color(0xFF2D5A3D), Color(0xFF1A3A26)],
      );
    }
    if (category.contains('Drinks') || category.contains('Cold')) {
      return const LinearGradient(
        colors: [Color(0xFF2E86AB), Color(0xFF1A5276)],
      );
    }
    if (category.contains('Noodles') || category.contains('Asian')) {
      return const LinearGradient(
        colors: [Color(0xFFC0392B), Color(0xFF922B21)],
      );
    }
    return const LinearGradient(
      colors: [Color(0xFF5D6D7E), Color(0xFF34495E)],
    );
  }

  Widget _iconForCategory(String category) {
    final icon = switch (category) {
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
    return Icon(icon, color: Colors.white.withOpacity(0.9), size: 28);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;

  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: AppTypography.label.copyWith(
          color: color,
          fontSize: 6,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
