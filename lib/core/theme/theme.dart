import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'colors.dart';
import 'typography.dart';

/// Provides [lightTheme] and [darkTheme] for Uni Eats.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildTheme(
        brightness: Brightness.light,
        bg: AppColors.lightBg,
        surface: AppColors.lightSurface,
        surface2: AppColors.lightSurface2,
        textPrimary: AppColors.lightTextPrimary,
        textSecondary: AppColors.lightTextSecondary,
        textMuted: AppColors.lightTextMuted,
        border: AppColors.lightBorder,
      );

  static ThemeData get darkTheme => _buildTheme(
        brightness: Brightness.dark,
        bg: AppColors.darkSurface2,
        surface: AppColors.darkSurface3,
        surface2: AppColors.darkSurface2,
        textPrimary: AppColors.darkTextPrimary,
        textSecondary: AppColors.darkTextSecondary,
        textMuted: AppColors.darkTextMuted,
        border: AppColors.darkBorder,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color bg,
    required Color surface,
    required Color surface2,
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
    required Color border,
  }) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surface2,
        outline: border,
      ),
      fontFamily: 'Satoshi',
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: textPrimary),
        headlineMedium: AppTypography.heading.copyWith(color: textPrimary),
        titleMedium: AppTypography.subheading.copyWith(color: textPrimary),
        bodyMedium: AppTypography.body.copyWith(color: textSecondary),
        bodySmall: AppTypography.bodySmall.copyWith(color: textSecondary),
        labelLarge: AppTypography.button.copyWith(color: Colors.white),
        labelSmall: AppTypography.caption.copyWith(color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: textPrimary,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: AppColors.primary,
        labelStyle: AppTypography.caption.copyWith(color: textSecondary),
        secondaryLabelStyle: AppTypography.caption.copyWith(color: Colors.white),
        shape: const StadiumBorder(),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        hintStyle: AppTypography.body.copyWith(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: AppTypography.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    );
  }
}
