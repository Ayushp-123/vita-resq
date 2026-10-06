import 'package:flutter/material.dart';

/// Centralized shape system for Vita ResQ.
///
/// Design direction: SOFT + ROUNDED
/// Uses gentle, approachable curves that feel human and modern,
/// avoiding harsh corners while preserving structural clarity.
class AppShapes {
  AppShapes._();

  // -------------------------------------------------------------
  // CORNER RADII TOKENS
  // -------------------------------------------------------------
  /// Small radius (10dp) - Chips, badges, small tags
  static const double radiusSm = 10.0;

  /// Medium radius (16dp) - Standard buttons, sheet headers, small cards
  static const double radiusMd = 16.0;

  /// Large radius (24dp) - Main content cards, bottom sheets, dialogs
  static const double radiusLg = 24.0;

  /// Extra small radius (6dp) - Micro-indicators, tooltips
  static const double radiusXs = 6.0;

  /// Extra large radius (32dp) - Floating action surfaces, hero banners
  static const double radiusXl = 32.0;

  /// Full pill / capsule radius
  static const double radiusPill = 100.0;

  // -------------------------------------------------------------
  // COMPONENT-SPECIFIC RADII
  // -------------------------------------------------------------
  /// Button corner radius (16dp)
  static const double buttonRadius = 16.0;

  /// Text field / dropdown corner radius (14dp)
  static const double inputRadius = 14.0;

  /// Card / surface corner radius (20dp)
  static const double cardRadius = 20.0;

  /// Dialog / modal corner radius (24dp)
  static const double dialogRadius = 24.0;

  /// Status badge corner radius (8dp)
  static const double statusBadgeRadius = 8.0;

  // -------------------------------------------------------------
  // BORDER RADIUS HELPERS
  // -------------------------------------------------------------
  static const BorderRadius small = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius medium = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius large = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius extraLarge = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(radiusPill));

  static const BorderRadius button = BorderRadius.all(Radius.circular(buttonRadius));
  static const BorderRadius input = BorderRadius.all(Radius.circular(inputRadius));
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardRadius));
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(dialogRadius));
  static const BorderRadius statusBadge = BorderRadius.all(Radius.circular(statusBadgeRadius));

  // -------------------------------------------------------------
  // SHAPE BORDERS FOR THEMES
  // -------------------------------------------------------------
  static const RoundedRectangleBorder buttonShape = RoundedRectangleBorder(borderRadius: button);
  static const RoundedRectangleBorder cardShape = RoundedRectangleBorder(borderRadius: card);
  static const RoundedRectangleBorder dialogShape = RoundedRectangleBorder(borderRadius: dialog);
}
