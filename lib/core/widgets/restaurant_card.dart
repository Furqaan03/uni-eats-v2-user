import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/restaurant/providers/restaurant_status_provider.dart';
import '../../models/restaurant_model.dart';
import '../../utils/currency_formatter.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class RestaurantCard extends ConsumerWidget {
  final RestaurantModel restaurant;
  final VoidCallback? onTap;
  final double width;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.onTap,
    this.width = 140,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textSecondary = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final status = ref.watch(restaurantStatusProvider(restaurant.id)).valueOrNull ??
        RestaurantStatus(isOpen: restaurant.isOpen, isBusy: restaurant.isBusy);

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
            _buildImage(status),
            Padding(
              padding: const EdgeInsets.all(10),
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
                    '⭐ ${restaurant.rating} · ${restaurant.building}',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                  if (restaurant.discountPercent != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Text(
                              CurrencyFormatter.format(15),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.accent,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              CurrencyFormatter.format(10.50),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        'from ${CurrencyFormatter.format(restaurant.minOrder)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
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

  Widget _buildImage(RestaurantStatus status) {
    final gradientColors = _gradientForCategory(restaurant.category);
    final String? badgeLabel = !status.isOpen ? 'CLOSED' : (status.isBusy ? 'BUSY' : 'OPEN');
    final Color badgeColor = !status.isOpen
        ? AppColors.danger
        : (status.isBusy ? Colors.orange : AppColors.primary);
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        children: [
          if (!status.isOrderable)
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.45)),
            ),
          if (badgeLabel != null)
            Positioned(
              bottom: 6,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeLabel,
                  style: AppTypography.label.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          if (restaurant.discountPercent != null)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${restaurant.discountPercent!.toInt()}% OFF',
                  style: AppTypography.label.copyWith(
                    color: AppColors.accent,
                    fontSize: 7,
                  ),
                ),
              ),
            ),
        ],
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
