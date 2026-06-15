import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/typography.dart';

class UniSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const UniSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search restaurants or dishes...',
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurface3 : AppColors.lightSurface;
    final mutedColor = isDark ? AppColors.darkTextMuted : const Color(0xFF9AB09A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: mutedColor),
            const SizedBox(width: 10),
            Expanded(
              child: onChanged != null
                  ? TextField(
                      controller: controller,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: hint,
                        hintStyle: AppTypography.body.copyWith(color: mutedColor),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      hint,
                      style: AppTypography.body.copyWith(color: mutedColor),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
