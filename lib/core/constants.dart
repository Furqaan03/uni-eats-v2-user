import 'package:flutter/material.dart';

/// App-wide constants.
class AppConstants {
  AppConstants._();

  static const String appName = 'Uni Eats';
  static const String tagline = 'Your Campus. Your Way.';

  // Currency
  static const String currency = 'QAR';
  static const String currencySymbol = 'QAR ';

  // Animation durations
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);

  // Spacing scale
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;

  // Radius scale
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 50;

  // Screen edge padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: 16);
}
