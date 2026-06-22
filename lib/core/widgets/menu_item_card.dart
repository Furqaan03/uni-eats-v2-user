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
  /// Override availability — pass false to show "Unavailable" state.
  final bool isAvailable;

  const MenuItemCard({
    super.key,
    required this.item,
    this.quantity,
    this.onAdd,
    this.onRemove,
    this.isAvailable = true,
  });

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuItemDetailSheet(
        item: item,
        quantity: quantity,
        isAvailable: isAvailable,
        onAdd: onAdd,
        onRemove: onRemove,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final mutedColor = isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted;
    final unavailable = !isAvailable;

    return Opacity(
      opacity: unavailable ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: () => _showDetail(context),
        child: Container(
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
                      if (unavailable)
                        _Tag(label: 'UNAVAILABLE', color: AppColors.danger)
                      else ...[
                        if (item.isBestseller)
                          _Tag(label: 'BESTSELLER', color: AppColors.accent),
                        if (item.isNew)
                          _Tag(label: 'NEW', color: AppColors.primary),
                        if (item.isPopular)
                          _Tag(label: 'POPULAR', color: AppColors.star),
                      ],
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
                  if (item.hasDiscount)
                    Row(
                      children: [
                        Text(
                          CurrencyFormatter.format(item.effectivePrice),
                          style: AppTypography.subheading.copyWith(
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          CurrencyFormatter.format(item.price),
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            fontSize: 10,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '-${item.discountPercent!.toInt()}%',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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
            if (unavailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.block, size: 16, color: AppColors.danger),
              )
            else if (quantity == null)
              GestureDetector(
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
            else
              Container(
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
      ),
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

// ── Item detail bottom sheet ───────────────────────────────────────────────

class _MenuItemDetailSheet extends StatelessWidget {
  final MenuItemModel item;
  final int? quantity;
  final bool isAvailable;
  final VoidCallback? onAdd;
  final VoidCallback? onRemove;

  const _MenuItemDetailSheet({
    required this.item,
    required this.quantity,
    required this.isAvailable,
    this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E2A1E) : Colors.white;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted = isDark ? const Color(0xFF8A9E8A) : const Color(0xFF8A9E8A);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Hero image / icon
          Container(
            height: 140,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: _gradientForCategory(item.category),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: _iconForCategory(item.category, size: 56),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tags row
                if (item.isBestseller || item.isNew || item.isPopular || !isAvailable)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        if (!isAvailable)
                          _Tag(label: 'UNAVAILABLE', color: AppColors.danger),
                        if (item.isBestseller)
                          _Tag(label: 'BESTSELLER', color: AppColors.accent),
                        if (item.isNew)
                          _Tag(label: 'NEW', color: AppColors.primary),
                        if (item.isPopular)
                          _Tag(label: 'POPULAR', color: AppColors.star),
                      ],
                    ),
                  ),

                // Name & price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.heading.copyWith(
                          color: textPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (item.hasDiscount)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(item.effectivePrice),
                            style: AppTypography.heading.copyWith(
                              color: AppColors.primary,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(item.price),
                            style: AppTypography.caption.copyWith(
                              color: textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        CurrencyFormatter.format(item.price),
                        style: AppTypography.heading.copyWith(
                          color: AppColors.primary,
                          fontSize: 18,
                        ),
                      ),
                  ],
                ),

                // Category
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: AppTypography.caption.copyWith(color: textMuted),
                ),

                // Description
                if (item.description != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    item.description!,
                    style: AppTypography.body.copyWith(
                      color: isDark ? Colors.white70 : Colors.black54,
                      height: 1.5,
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Add/Remove controls or Unavailable badge
                if (!isAvailable)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.block, size: 16, color: AppColors.danger),
                      label: const Text('Currently Unavailable',
                          style: TextStyle(color: AppColors.danger)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  )
                else if (quantity == null || quantity == 0)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        onAdd?.call();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'In cart',
                          style: AppTypography.body.copyWith(color: textMuted),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF263226) : const Color(0xFFF0F7F0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                onRemove?.call();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.remove, size: 18),
                              color: AppColors.primary,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                            Text(
                              '$quantity',
                              style: AppTypography.subheading.copyWith(
                                color: textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                onAdd?.call();
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.add, size: 18),
                              color: AppColors.primary,
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _gradientForCategory(String category) {
    if (category.contains('Coffee')) return const LinearGradient(colors: [Color(0xFF6B4226), Color(0xFF3E2616)]);
    if (category.contains('Bakery')) return const LinearGradient(colors: [Color(0xFFD4A373), Color(0xFFA97142)]);
    if (category.contains('Healthy') || category.contains('Bowls')) return const LinearGradient(colors: [Color(0xFF2D5A3D), Color(0xFF1A3A26)]);
    if (category.contains('Drinks') || category.contains('Cold')) return const LinearGradient(colors: [Color(0xFF2E86AB), Color(0xFF1A5276)]);
    if (category.contains('Noodles') || category.contains('Asian')) return const LinearGradient(colors: [Color(0xFFC0392B), Color(0xFF922B21)]);
    return const LinearGradient(colors: [Color(0xFF5D6D7E), Color(0xFF34495E)]);
  }

  Widget _iconForCategory(String category, {double size = 28}) {
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
    return Icon(icon, color: Colors.white.withOpacity(0.9), size: size);
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
