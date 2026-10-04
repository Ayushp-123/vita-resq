import 'package:flutter/material.dart';

class AppTheme {
  // -------------------------------------------------------------
  // BRAND IDENTITY: VITA RESQ DEEP NAVY & SLATE
  // -------------------------------------------------------------
  static const Color primaryNavy = Color(0xFF0F172A); // Deep Slate Navy (Brand Identity)
  static const Color secondaryNavy = Color(0xFF1E293B); // Slate 800
  static const Color tertiaryNavy = Color(0xFF334155); // Slate 700

  static const Color brandBlue = Color(0xFF2563EB); // Dynamic Action Blue
  static const Color brandDarkBlue = Color(0xFF1D4ED8);
  static const Color brandLightBlue = Color(0xFFEFF6FF);

  // Backward-compatible aliases
  static const Color secondaryBlue = brandBlue;
  static const Color secondaryDarkBlue = brandDarkBlue;
  static const Color secondaryContainerBlue = brandLightBlue;
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF1E40AF);

  // -------------------------------------------------------------
  // EMERGENCY RED (Reserved strictly for SOS & Critical Danger)
  // -------------------------------------------------------------
  static const Color emergencyRed = Color(0xFFDC2626); // High-Vis Red 600
  static const Color emergencyDarkRed = Color(0xFFB91C1C); // Deep Red 700
  static const Color emergencyLightRed = Color(0xFFFEF2F2); // Red 50
  static const Color primaryRed = emergencyRed;
  static const Color primaryDarkRed = emergencyDarkRed;
  static const Color primaryContainerRed = emergencyLightRed;
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF991B1B);

  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorContainer = Color(0xFFFEE2E2);

  // -------------------------------------------------------------
  // ACTIVE HELP & CONFIRMED SAFETY (Emerald Green)
  // -------------------------------------------------------------
  static const Color emeraldGreen = Color(0xFF10B981); // Emerald 500
  static const Color emeraldDark = Color(0xFF059669); // Emerald 600
  static const Color emeraldContainer = Color(0xFFECFDF5); // Emerald 50
  static const Color onEmerald = Color(0xFFFFFFFF);

  // -------------------------------------------------------------
  // CAUTION & STANDBY (High-Vis Amber)
  // -------------------------------------------------------------
  static const Color tertiaryAmber = Color(0xFFF59E0B);
  static const Color tertiaryDarkAmber = Color(0xFFD97706);
  static const Color tertiaryContainerAmber = Color(0xFFFFFBEB);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF92400E);

  // -------------------------------------------------------------
  // MODERN NEUTRAL SURFACES & ACCESSIBLE TYPOGRAPHY
  // -------------------------------------------------------------
  static const Color surfaceLight = Color(0xFFF8FAFC); // Clean neutral background (Slate 50)
  static const Color surfaceLow = Color(0xFFF1F5F9); // Slate 100
  static const Color surfaceContainer = Color(0xFFE2E8F0); // Slate 200
  static const Color surfaceHighest = Color(0xFFCBD5E1); // Slate 300
  static const Color surfaceLowest = Color(0xFFFFFFFF); // Pure white card surface
  static const Color surfaceDim = Color(0xFF94A3B8); // Slate 400

  static const Color onSurface = Color(0xFF0F172A); // High-contrast Slate 900
  static const Color onSurfaceVariant = Color(0xFF64748B); // Slate 500
  static const Color outlineColor = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFCBD5E1);

  // Gradients for High-Stress Emergency Controls
  static const LinearGradient emergencyGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandBlueGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cyberBlueGradient = brandBlueGradient;

  static const LinearGradient navyHeaderGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGlassGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient amberGradient = LinearGradient(
    colors: [Color(0xFFFBBF24), Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadows
  static List<BoxShadow> glowShadow(Color color, {double blur = 24, double spread = 0, Offset offset = const Offset(0, 8)}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: spread,
        offset: offset,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: blur / 2,
        spreadRadius: spread,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primaryNavy,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFF1E293B),
        onPrimaryContainer: Colors.white,
        secondary: brandBlue,
        onSecondary: Colors.white,
        secondaryContainer: brandLightBlue,
        onSecondaryContainer: Color(0xFF1E40AF),
        tertiary: tertiaryAmber,
        onTertiary: Colors.white,
        tertiaryContainer: tertiaryContainerAmber,
        onTertiaryContainer: onTertiaryContainer,
        error: emergencyRed,
        onError: Colors.white,
        errorContainer: emergencyLightRed,
        onErrorContainer: Color(0xFF991B1B),
        surface: surfaceLight,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: outlineColor,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: surfaceLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        foregroundColor: primaryNavy,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: primaryNavy,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: primaryNavy),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryNavy,
          minimumSize: const Size(double.infinity, 52),
          side: const BorderSide(color: outlineColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: brandBlue, width: 2),
        ),
        labelStyle: const TextStyle(color: onSurfaceVariant, fontSize: 14),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      ),
    );
  }
}
