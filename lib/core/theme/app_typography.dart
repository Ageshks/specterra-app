import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Typography scale built on the bundled Plus Jakarta Sans variable font.
///
/// Because the asset is a variable font, each style carries both a [FontWeight]
/// (so Flutter picks the right face for fallbacks and semantics) and a `wght`
/// axis variation (so the correct weight is rendered from the single file).
abstract final class AppTypography {
  static const String fontFamily = 'Plus Jakarta Sans';

  static TextStyle style(
    double size,
    FontWeight weight, {
    Color color = AppColors.ink,
    double? height,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontWeight: weight,
      fontVariations: [FontVariation('wght', weight.value.toDouble())],
    );
  }

  static final TextTheme textTheme = TextTheme(
    displayLarge: style(40, FontWeight.w800, height: 1.1, letterSpacing: -1),
    displayMedium: style(
      32,
      FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.6,
    ),
    displaySmall: style(28, FontWeight.w700, height: 1.2, letterSpacing: -0.4),
    headlineMedium: style(
      24,
      FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.3,
    ),
    headlineSmall: style(20, FontWeight.w700, height: 1.3, letterSpacing: -0.2),
    titleLarge: style(18, FontWeight.w700, height: 1.35, letterSpacing: -0.1),
    titleMedium: style(16, FontWeight.w600, height: 1.35),
    titleSmall: style(14.5, FontWeight.w600, height: 1.4),
    bodyLarge: style(
      15,
      FontWeight.w400,
      height: 1.5,
      color: AppColors.inkSoft,
    ),
    bodyMedium: style(
      13.5,
      FontWeight.w500,
      height: 1.5,
      color: AppColors.inkSoft,
    ),
    bodySmall: style(12, FontWeight.w500, height: 1.45, color: AppColors.muted),
    labelLarge: style(15, FontWeight.w700, height: 1.2),
    labelMedium: style(13, FontWeight.w600, height: 1.2),
    labelSmall: style(11, FontWeight.w700, height: 1.2, letterSpacing: 0.4),
  );

  /// Tabular-ish style for booking IDs, prices and metric values.
  static TextStyle mono(
    double size,
    FontWeight weight, {
    Color color = AppColors.ink,
  }) => style(size, weight, color: color, letterSpacing: 0.2);
}
