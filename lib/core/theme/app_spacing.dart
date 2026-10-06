import 'package:flutter/material.dart';

/// Centralized spacing and sizing scale for Vita ResQ.
///
/// Ensures consistent rhythm, comfortable mobile touch interactions,
/// and eliminates arbitrary ad-hoc padding across screens.
class AppSpacing {
  AppSpacing._();

  // -------------------------------------------------------------
  // SPACING SCALE (8PT GRID ALIGNED)
  // -------------------------------------------------------------
  /// 2dp - Micro adjustments, divider offsets
  static const double xxs = 2.0;

  /// 4dp - Tight element gaps, badge insets
  static const double xs = 4.0;

  /// 8dp - Element padding, chip spacing, compact gap
  static const double sm = 8.0;

  /// 12dp - Medium gap, text field internal padding
  static const double md = 12.0;

  /// 16dp - Standard card padding, list item separation
  static const double lg = 16.0;

  /// 20dp - Screen horizontal edge padding, large card padding
  static const double xl = 20.0;

  /// 24dp - Dialog padding, section gap
  static const double xxl = 24.0;

  /// 32dp - Hero container separation, modal bottom gap
  static const double xxxl = 32.0;

  /// 40dp - Prominent landmark spacing
  static const double huge = 40.0;

  /// 48dp - Major top/bottom breathing room
  static const double massive = 48.0;

  // -------------------------------------------------------------
  // ACCESSIBILITY & TOUCH TARGET SIZING
  // -------------------------------------------------------------
  /// Minimum touch target size (48x48dp per Material / WCAG standards)
  static const double minTouchTarget = 48.0;

  /// Standard primary action button height (52dp)
  static const double buttonHeight = 52.0;

  /// Compact action button height (40dp)
  static const double buttonHeightSm = 40.0;

  /// Standard input text field height (52dp)
  static const double inputHeight = 52.0;

  /// Standard icon button dimension (48dp)
  static const double iconButtonSize = 48.0;

  // -------------------------------------------------------------
  // ICON SIZING SCALE
  // Outline-preferred icons with consistent weight
  // -------------------------------------------------------------
  /// Extra small icon (14dp) - Metadata chips, inline status
  static const double iconXs = 14.0;

  /// Small icon (18dp) - Secondary chips, list trailing chevrons
  static const double iconSm = 18.0;

  /// Medium icon (22dp) - Standard body icon, navigation, action prefix
  static const double iconMd = 22.0;

  /// Large icon (28dp) - Prominent action cards, list avatars
  static const double iconLg = 28.0;

  /// Extra large icon (36dp) - Header icons, alert modals
  static const double iconXl = 36.0;

  /// Hero icon (48dp) - Empty state illustrations, major status circles
  static const double iconHero = 48.0;

  // -------------------------------------------------------------
  // SCREEN & CONTAINER INSETS
  // -------------------------------------------------------------
  /// Standard screen edge padding
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: xl, vertical: lg);
  static const EdgeInsets screenPaddingHorizontal = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets screenPaddingVertical = EdgeInsets.symmetric(vertical: lg);

  /// Card internal insets
  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLg = EdgeInsets.all(xl);
  static const EdgeInsets cardPaddingSm = EdgeInsets.all(md);

  /// Dialog internal insets
  static const EdgeInsets dialogPadding = EdgeInsets.all(xxl);

  /// Input field content padding
  static const EdgeInsets inputPadding = EdgeInsets.symmetric(horizontal: lg, vertical: 14.0);

  /// Button padding
  static const EdgeInsets buttonPadding = EdgeInsets.symmetric(horizontal: xl, vertical: 14.0);
  static const EdgeInsets buttonPaddingSm = EdgeInsets.symmetric(horizontal: md, vertical: sm);

  /// Status badge insets
  static const EdgeInsets statusBadgePadding = EdgeInsets.symmetric(horizontal: sm + 2, vertical: xs + 1);

  // -------------------------------------------------------------
  // REUSABLE SIZEDBOX GAPS
  // -------------------------------------------------------------
  static const SizedBox gapHorizontalXs = SizedBox(width: xs);
  static const SizedBox gapHorizontalSm = SizedBox(width: sm);
  static const SizedBox gapHorizontalMd = SizedBox(width: md);
  static const SizedBox gapHorizontalLg = SizedBox(width: lg);
  static const SizedBox gapHorizontalXl = SizedBox(width: xl);

  static const SizedBox gapVerticalXs = SizedBox(height: xs);
  static const SizedBox gapVerticalSm = SizedBox(height: sm);
  static const SizedBox gapVerticalMd = SizedBox(height: md);
  static const SizedBox gapVerticalLg = SizedBox(height: lg);
  static const SizedBox gapVerticalXl = SizedBox(height: xl);
  static const SizedBox gapVerticalXxl = SizedBox(height: xxl);
  static const SizedBox gapVerticalXxxl = SizedBox(height: xxxl);
  static const SizedBox gapVerticalHuge = SizedBox(height: huge);
}
