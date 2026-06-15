import 'package:flutter/material.dart';

/// Uni Eats brand palette
///
/// Brand naming rule: "Uni Eats" is always two words.
/// Never use pure black (#000000) or pure white (#FFFFFF) as backgrounds.
class AppColors {
  AppColors._();

  // Primary brand greens
  static const Color primary = Color(0xFF02BA26);
  static const Color primaryDark = Color(0xFF106C2F);
  static const Color primaryLight = Color(0xFF4BD96F);

  // Accent
  static const Color accent = Color(0xFFFF7A00);
  static const Color accentDark = Color(0xFFC45A00);
  static const Color star = Color(0xFFFFB800);
  static const Color danger = Color(0xFFFF4444);

  // Dark theme
  static const Color darkBg = Color(0xFF0D0F0D);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color darkSurface2 = Color(0xFF222C22);
  static const Color darkSurface3 = Color(0xFF2A362A);
  static const Color darkTextPrimary = Color(0xFFEFF4EF);
  static const Color darkTextSecondary = Color(0xFF8AA08A);
  static const Color darkTextMuted = Color(0xFF506050);
  static const Color darkBorder = Color(0xFF3A4E3A);

  // Light theme
  static const Color lightBg = Color(0xFFEFF3EE);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF5F8F5);
  static const Color lightTextPrimary = Color(0xFF0D1F0D);
  static const Color lightTextSecondary = Color(0xFF5A7A5A);
  static const Color lightTextMuted = Color(0xFF9AB09A);
  static const Color lightBorder = Color(0xFFD8E8D8);

  // Gradients
  static const LinearGradient walletGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient flashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, accentDark],
  );
}
