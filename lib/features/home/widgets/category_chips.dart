import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';

class CategoryChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const CategoryChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  // label -> (emoji shown inside the circle, full chip label used for filtering)
  static const List<(String emoji, String label)> categories = [
    ('🍽️', 'All'),
    ('☕', '☕ Coffee'),
    ('🍔', '🍔 Food'),
    ('🥗', '🥗 Healthy'),
    ('🍰', '🍰 Dessert'),
    ('🥤', '🥤 Drinks'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).colorScheme.onSurface;

    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final (emoji, label) = categories[index];
          final isSelected = label == selected;
          final displayName = label == 'All' ? 'All' : label.substring(2).trim();

          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: GestureDetector(
              onTap: () => onSelected(label),
              child: Column(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : isDark
                              ? AppColors.darkSurface3
                              : AppColors.lightSurface,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                      boxShadow: isDark || isSelected
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    style: AppTypography.caption.copyWith(
                      color: isSelected ? AppColors.primary : textPrimary,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
