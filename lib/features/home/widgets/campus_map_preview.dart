import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../campus_map/campus_map_painter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../services/mock_data_service.dart';

class CampusMapPreview extends StatelessWidget {
  const CampusMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.go('/tracking'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 130,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface3 : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
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
        child: Stack(
          children: [
            CustomPaint(
              painter: CampusMapPainter(
                locations: MockDataService.campusLocations,
              ),
              size: Size.infinite,
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface3.withOpacity(0.85)
                      : Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '3 places within 10 min',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
