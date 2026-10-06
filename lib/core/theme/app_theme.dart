import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_shapes.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

export 'app_colors.dart';
export 'app_shapes.dart';
export 'app_typography.dart';
export 'app_spacing.dart';
export 'app_motion.dart';
export 'app_status.dart';

/// Centralized Material 3 Theme Configuration for Vita ResQ.
///
/// Embodies the HUMAN + PROFESSIONAL design direction:
/// - Warm off-white primary canvas
/// - Very subtle blue-gray secondary surface
/// - Deep navy structure and readable typography
/// - Emergency red strictly guarded for SOS and danger states
/// - Soft blue for location, routing, and primary navigation
/// - Emerald green for safety and verification
/// - Amber for caution and warnings
class AppTheme {
  AppTheme._();

  // -------------------------------------------------------------
  // BRAND IDENTITY & CORE TOKENS (BACKWARD-COMPATIBLE ALIASES)
  // -------------------------------------------------------------
  static const Color primaryNavy = AppColors.deepNavy; // 0xFF0F172A
  static const Color secondaryNavy = AppColors.navy800; // 0xFF1E293B
  static const Color tertiaryNavy = AppColors.navy700; // 0xFF334155

  static const Color brandBlue = AppColors.softBlue; // 0xFF2563EB
  static const Color brandDarkBlue = AppColors.softBlueDark;
  static const Color brandLightBlue = AppColors.softBlueLight;

  static const Color secondaryBlue = brandBlue;
  static const Color secondaryDarkBlue = brandDarkBlue;
  static const Color secondaryContainerBlue = brandLightBlue;
  static const Color onSecondary = AppColors.onSoftBlue;
  static const Color onSecondaryContainer = AppColors.onSoftBlueContainer;

  // -------------------------------------------------------------
  // EMERGENCY RED (RESERVED STRICTLY FOR SOS & DANGER)
  // -------------------------------------------------------------
  static const Color emergencyRed = AppColors.emergencyRed; // 0xFFDC2626
  static const Color emergencyDarkRed = AppColors.emergencyDarkRed;
  static const Color emergencyLightRed = AppColors.emergencyLightRed;
  static const Color primaryRed = emergencyRed;
  static const Color primaryDarkRed = emergencyDarkRed;
  static const Color primaryContainerRed = emergencyLightRed;
  static const Color onPrimary = AppColors.onEmergency;
  static const Color onPrimaryContainer = AppColors.onEmergencyContainer;

  static const Color errorRed = Color(0xFFEF4444);
  static const Color errorContainer = AppColors.emergencyContainer;

  // -------------------------------------------------------------
  // ACTIVE HELP & CONFIRMED SAFETY (EMERALD GREEN)
  // -------------------------------------------------------------
  static const Color emeraldGreen = AppColors.emeraldGreen; // 0xFF10B981
  static const Color emeraldDark = AppColors.emeraldDark;
  static const Color emeraldContainer = AppColors.emeraldLight;
  static const Color onEmerald = AppColors.onEmerald;

  // -------------------------------------------------------------
  // CAUTION & STANDBY (HIGH-VIS AMBER)
  // -------------------------------------------------------------
  static const Color tertiaryAmber = AppColors.warningAmber; // 0xFFF59E0B
  static const Color tertiaryDarkAmber = AppColors.amberDark;
  static const Color tertiaryContainerAmber = AppColors.amberLight;
  static const Color onTertiary = AppColors.onAmber;
  static const Color onTertiaryContainer = AppColors.onAmberContainer;

  // -------------------------------------------------------------
  // MODERN NEUTRAL SURFACES & ACCESSIBLE TYPOGRAPHY
  // -------------------------------------------------------------
  static const Color surfaceLight = Color(0xFFF8FAFC); // Slate 50 (test baseline preserved)
  static const Color surfaceLow = AppColors.subtleBlueGray; // 0xFFF1F5F9
  static const Color surfaceContainer = AppColors.borderSubtle; // 0xFFE2E8F0
  static const Color surfaceHighest = AppColors.borderMedium; // 0xFFCBD5E1
  static const Color surfaceLowest = AppColors.surfacePureWhite; // 0xFFFFFFFF
  static const Color surfaceDim = AppColors.textMuted; // 0xFF94A3B8

  static const Color onSurface = AppColors.textPrimary; // 0xFF0F172A
  static const Color onSurfaceVariant = AppColors.onSurfaceVariant; // 0xFF64748B
  static const Color outlineColor = AppColors.borderSubtle; // 0xFFE2E8F0
  static const Color outlineVariant = AppColors.borderMedium; // 0xFFCBD5E1

  // -------------------------------------------------------------
  // GRADIENTS
  // -------------------------------------------------------------
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

  // -------------------------------------------------------------
  // SHADOWS
  // -------------------------------------------------------------
  static List<BoxShadow> glowShadow(
    Color color, {
    double blur = 24,
    double spread = 0,
    Offset offset = const Offset(0, 8),
  }) {
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

  /// Subtle card shadow (calm, non-harsh)
  static List<BoxShadow> get cardShadow => const [
    BoxShadow(
      color: AppColors.shadowSubtle,
      blurRadius: 10,
      spreadRadius: 0,
      offset: Offset(0, 2),
    ),
  ];

  // -------------------------------------------------------------
  // MATERIAL 3 LIGHT THEME SPECIFICATION
  // -------------------------------------------------------------
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      textTheme: AppTypography.textTheme,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.deepNavy,
        onPrimary: AppColors.textOnDark,
        primaryContainer: AppColors.navy800,
        onPrimaryContainer: AppColors.textOnDark,
        secondary: AppColors.softBlue,
        onSecondary: AppColors.onSoftBlue,
        secondaryContainer: AppColors.softBlueLight,
        onSecondaryContainer: AppColors.onSoftBlueContainer,
        tertiary: AppColors.warningAmber,
        onTertiary: AppColors.onAmber,
        tertiaryContainer: AppColors.amberLight,
        onTertiaryContainer: AppColors.onAmberContainer,
        error: AppColors.emergencyRed,
        onError: AppColors.onEmergency,
        errorContainer: AppColors.emergencyContainer,
        onErrorContainer: AppColors.onEmergencyContainer,
        surface: AppColors.warmOffWhite,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.borderSubtle,
        outlineVariant: AppColors.borderMedium,
      ),
      scaffoldBackgroundColor: AppColors.warmOffWhite,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.warmOffWhite,
        foregroundColor: AppColors.deepNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.pageHeading,
        iconTheme: IconThemeData(
          color: AppColors.deepNavy,
          size: AppSpacing.iconMd,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepNavy,
          foregroundColor: AppColors.textOnDark,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: AppShapes.buttonShape,
          textStyle: AppTypography.buttonText,
          padding: AppSpacing.buttonPadding,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepNavy,
          minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
          shape: AppShapes.buttonShape,
          textStyle: AppTypography.buttonText,
          padding: AppSpacing.buttonPadding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.softBlue,
          textStyle: AppTypography.buttonText,
          shape: AppShapes.buttonShape,
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surfacePureWhite,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppShapes.card,
          side: BorderSide(color: AppColors.borderSubtle, width: 1.2),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfacePureWhite,
        contentPadding: AppSpacing.inputPadding,
        border: OutlineInputBorder(
          borderRadius: AppShapes.input,
          borderSide: BorderSide(color: AppColors.borderMedium, width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppShapes.input,
          borderSide: BorderSide(color: AppColors.borderSubtle, width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppShapes.input,
          borderSide: BorderSide(color: AppColors.softBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppShapes.input,
          borderSide: BorderSide(color: AppColors.emergencyRed, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppShapes.input,
          borderSide: BorderSide(color: AppColors.emergencyRed, width: 2),
        ),
        labelStyle: AppTypography.bodySecondary,
        hintStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        errorStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          color: AppColors.emergencyRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfacePureWhite,
        elevation: 0,
        selectedItemColor: AppColors.deepNavy,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
