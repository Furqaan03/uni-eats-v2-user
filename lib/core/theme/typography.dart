import 'package:flutter/material.dart';

/// Typography tokens for Uni Eats.
///
/// Primary font: Satoshi (brand + UI body)
class AppTypography {
  AppTypography._();

  static const String _primaryFont = 'Satoshi';
  static const String _secondaryFont = 'Satoshi';

  // Display / Hero
  static const TextStyle displayLarge = TextStyle(
    fontFamily: _primaryFont,
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: _primaryFont,
    fontSize: 20,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // Headings
  static const TextStyle heading = TextStyle(
    fontFamily: _primaryFont,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static const TextStyle subheading = TextStyle(
    fontFamily: _secondaryFont,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );

  // Body
  static const TextStyle body = TextStyle(
    fontFamily: _secondaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: _secondaryFont,
    fontSize: 11,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: _secondaryFont,
    fontSize: 10,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle label = TextStyle(
    fontFamily: _secondaryFont,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );

  static const TextStyle button = TextStyle(
    fontFamily: _primaryFont,
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  );

  static const TextStyle balance = TextStyle(
    fontFamily: _primaryFont,
    fontSize: 26,
    fontWeight: FontWeight.w900,
    letterSpacing: -1,
    height: 1.1,
  );
}
