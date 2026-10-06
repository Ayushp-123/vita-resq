import 'package:flutter/material.dart';

/// Centralized color system for Vita ResQ.
///
/// Design direction: HUMAN + PROFESSIONAL
/// - Trustworthy, approachable, calm, dependable, safety-focused, modern.
/// - Primary background: Warm Off-White
/// - Secondary surface: Very Subtle Blue-Gray
/// - Primary text / structure: Deep Navy
/// - Emergency: Emergency Red (strictly reserved for SOS and critical actions)
/// - Location / navigation: Soft Blue
/// - Success: Emerald Green
/// - Warning: Amber
class AppColors {
  AppColors._();

  // -------------------------------------------------------------
  // PRIMARY BACKGROUND & SURFACES (WARM + APPROACHABLE)
  // -------------------------------------------------------------
  /// Warm off-white primary background for screens (calm, human, non-sterile)
  static const Color warmOffWhite = Color(0xFFFBF9F5);
  static const Color primaryBackground = warmOffWhite;

  /// Pure white surface for elevated cards and modals
  static const Color surfacePureWhite = Color(0xFFFFFFFF);
  static const Color surfaceCard = surfacePureWhite;

  /// Very subtle blue-gray secondary surface for section headers, groupings, inputs
  static const Color subtleBlueGray = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceSecondary = subtleBlueGray;

  /// Subtle slate-50 neutral surface (backward-compatible)
  static const Color surfaceLight = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceLow = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceContainer = Color(0xFFE2E8F0); // Slate 200
  static const Color surfaceHighest = Color(0xFFCBD5E1); // Slate 300
  static const Color surfaceLowest = Color(0xFFFFFFFF); // Pure white
  static const Color surfaceDim = Color(0xFF94A3B8); // Slate 400

  // -------------------------------------------------------------
  // BORDERS & DIVIDERS
  // -------------------------------------------------------------
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200
  static const Color borderMedium = Color(0xFFCBD5E1); // Slate 300
  static const Color borderFocus = Color(0xFF2563EB); // Soft Blue
  static const Color divider = Color(0xFFE2E8F0);

  // -------------------------------------------------------------
  // PRIMARY TEXT & STRUCTURE (DEEP NAVY)
  // -------------------------------------------------------------
  /// Deep Navy - Brand identity, primary headings, structure
  static const Color deepNavy = Color(0xFF0F172A); // Slate 900
  static const Color primaryNavy = deepNavy; // Alias
  static const Color navy800 = Color(0xFF1E293B); // Slate 800
  static const Color navy700 = Color(0xFF334155); // Slate 700

  /// Typography colors
  static const Color textPrimary = Color(0xFF0F172A); // High-contrast Deep Navy
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color onSurfaceVariant = Color(0xFF64748B); // Slate 500

  // -------------------------------------------------------------
  // EMERGENCY RED (CRITICAL ACTION ONLY)
  // Reserved strictly for SOS, active emergencies, danger, destructive actions
  // -------------------------------------------------------------
  static const Color emergencyRed = Color(0xFFDC2626); // High-vis Red 600
  static const Color emergencyDarkRed = Color(0xFFB91C1C); // Red 700
  static const Color emergencyLightRed = Color(0xFFFEF2F2); // Red 50
  static const Color emergencyContainer = Color(0xFFFEE2E2); // Red 100
  static const Color onEmergency = Color(0xFFFFFFFF);
  static const Color onEmergencyContainer = Color(0xFF991B1B);

  // -------------------------------------------------------------
  // LOCATION & NAVIGATION (SOFT BLUE)
  // Calm, dependable, clear blue for GPS, route tracking, active navigation
  // -------------------------------------------------------------
  static const Color softBlue = Color(0xFF2563EB); // Dynamic Action Blue
  static const Color brandBlue = softBlue; // Alias
  static const Color softBlueDark = Color(0xFF1D4ED8); // Blue 700
  static const Color softBlueLight = Color(0xFFEFF6FF); // Blue 50
  static const Color softBlueBorder = Color(0xFFBFDBFE); // Blue 200
  static const Color onSoftBlue = Color(0xFFFFFFFF);
  static const Color onSoftBlueContainer = Color(0xFF1E40AF);

  // -------------------------------------------------------------
  // SUCCESS (EMERALD GREEN)
  // For verified safety, completed emergencies, badges, resolved alerts
  // -------------------------------------------------------------
  static const Color emeraldGreen = Color(0xFF10B981); // Emerald 500
  static const Color emeraldDark = Color(0xFF059669); // Emerald 600
  static const Color emeraldLight = Color(0xFFECFDF5); // Emerald 50
  static const Color emeraldBorder = Color(0xFFA7F3D0); // Emerald 200
  static const Color onEmerald = Color(0xFFFFFFFF);
  static const Color onEmeraldContainer = Color(0xFF065F46);

  // -------------------------------------------------------------
  // WARNING (AMBER)
  // For caution, sensor countdowns, standby responders, network warnings
  // -------------------------------------------------------------
  static const Color warningAmber = Color(0xFFF59E0B); // Amber 500
  static const Color amberDark = Color(0xFFD97706); // Amber 600
  static const Color amberLight = Color(0xFFFFFBEB); // Amber 50
  static const Color amberBorder = Color(0xFFFDE68A); // Amber 200
  static const Color onAmber = Color(0xFFFFFFFF);
  static const Color onAmberContainer = Color(0xFF92400E);

  // -------------------------------------------------------------
  // SUBTLE SHADOWS & OVERLAYS (NON-HARSH)
  // -------------------------------------------------------------
  static const Color shadowSubtle = Color(0x0A0F172A); // ~4% navy
  static const Color shadowMedium = Color(0x120F172A); // ~7% navy
  static const Color shadowCard = Color(0x0D0F172A); // ~5% navy
  static const Color overlayDark = Color(0x800F172A); // 50% navy scrim
}
