import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized typography system for Vita ResQ.
///
/// Personality: FRIENDLY + PROFESSIONAL
/// Uses clean, legible sans-serif hierarchy tailored for rapid readability
/// under stressful emergency conditions and high-clarity civilian interactions.
class AppTypography {
  AppTypography._();

  static const String fontFamily = 'Inter';

  // -------------------------------------------------------------
  // HEADINGS & DISPLAY
  // -------------------------------------------------------------
  /// Display / Major Heading (28sp, Bold, Deep Navy)
  /// Used for hero greetings, high-level impact totals, major emergency banners.
  static const TextStyle display = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.deepNavy,
    letterSpacing: -0.5,
    height: 1.25,
  );

  /// Page Heading (22sp, Bold, Deep Navy)
  /// Used for screen titles, modal headers, major card groups.
  static const TextStyle pageHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.3,
    height: 1.3,
  );

  /// Section Heading (18sp, SemiBold, Deep Navy)
  /// Used for section dividers, container titles, list headers.
  static const TextStyle sectionHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.2,
    height: 1.35,
  );

  /// Subheading (16sp, SemiBold, Deep Navy)
  /// Used for card titles, row headers, modal sub-headers.
  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.deepNavy,
    letterSpacing: -0.1,
    height: 1.4,
  );

  // -------------------------------------------------------------
  // BODY TEXT
  // -------------------------------------------------------------
  /// Body Regular (15sp, Regular, Deep Navy)
  /// Standard readable content, descriptions, instructions.
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  /// Body Medium (15sp, Medium, Deep Navy)
  /// Slightly emphasized body text, key descriptions, active list items.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: 0.1,
    height: 1.5,
  );

  /// Body Secondary (14sp, Regular, Slate 600)
  /// Secondary explanations, helper text, address details.
  static const TextStyle bodySecondary = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.45,
  );

  // -------------------------------------------------------------
  // LABELS, CAPTIONS & METADATA
  // -------------------------------------------------------------
  /// Caption (12sp, Medium, Slate 500)
  /// Secondary badges, form hints, inline helper notes.
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  /// Metadata (11sp, SemiBold, Slate 500, Slightly Tracked)
  /// Timestamps, coordinates, telemetry markers, technical badges.
  static const TextStyle metadata = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
    height: 1.3,
  );

  // -------------------------------------------------------------
  // ACTIONS & BUTTONS
  // -------------------------------------------------------------
  /// Button Text (15sp, SemiBold, Accessible Letter Spacing)
  /// Standard primary, secondary, and outlined button labels.
  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  /// Compact Button Text (13sp, SemiBold)
  /// For small inline action chips, secondary triggers.
  static const TextStyle buttonTextSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  // -------------------------------------------------------------
  // EMERGENCY & NUMERICS (MISSION-CRITICAL READABILITY)
  // -------------------------------------------------------------
  /// Emergency Status (14sp, Bold, Emergency Red, Tracked)
  /// Reserved strictly for critical emergency indicators, SOS state banners.
  static const TextStyle emergencyStatus = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w800,
    color: AppColors.emergencyRed,
    letterSpacing: 0.8,
    height: 1.2,
  );

  /// Numeric Display (26sp, Bold, Deep Navy)
  /// For prominent ETA, distance, speed drop, score metrics.
  static const TextStyle numericDisplay = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.deepNavy,
    letterSpacing: -0.5,
    height: 1.2,
  );

  /// Numeric Compact (16sp, Bold, Deep Navy)
  /// For inline ETA chips, distance meters, countdown counters.
  static const TextStyle numericCompact = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.deepNavy,
    letterSpacing: -0.2,
    height: 1.2,
  );

  // -------------------------------------------------------------
  // MATERIAL TEXT THEME ADAPTER
  // -------------------------------------------------------------
  static TextTheme get textTheme => const TextTheme(
    displayLarge: display,
    headlineMedium: pageHeading,
    titleLarge: sectionHeading,
    titleMedium: subheading,
    bodyLarge: bodyMedium,
    bodyMedium: body,
    bodySmall: bodySecondary,
    labelLarge: buttonText,
    labelMedium: caption,
    labelSmall: metadata,
  );
}
