import 'package:flutter/material.dart';

/// Tokens from `docs/design.md` YAML `colors:` plus §4 primary palette names.
class AppColors {
  AppColors._();

  // --- §4 Primary palette (verbatim hex from design.md) ---

  static const Color warmIvory = Color(0xFFF7F4EC);
  static const Color softMist = Color(0xFFCFE8E2);
  static const Color teal = Color(0xFF3AA89E);
  static const Color deepTeal = Color(0xFF1E5E5A);
  static const Color softCoral = Color(0xFFFF7A66);
  static const Color warmGold = Color(0xFFFFC857);
  static const Color inkNavy = Color(0xFF1D2330);

  // --- design.md frontmatter `colors:` ---

  static const Color surface = Color(0xFFF6FAF8);
  static const Color surfaceDim = Color(0xFFD6DBD9);
  static const Color surfaceBright = Color(0xFFF6FAF8);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F5F3);
  static const Color surfaceContainer = Color(0xFFEAEFED);
  static const Color surfaceContainerHigh = Color(0xFFE4E9E7);
  static const Color surfaceContainerHighest = Color(0xFFDFE3E2);
  static const Color onSurface = Color(0xFF171D1C);
  static const Color onSurfaceVariant = Color(0xFF3D4947);
  static const Color inverseSurface = Color(0xFF2C3130);
  static const Color inverseOnSurface = Color(0xFFEDF2F0);
  static const Color outline = Color(0xFF6D7A77);
  static const Color outlineVariant = Color(0xFFBCC9C6);
  static const Color surfaceTint = Color(0xFF006A63);
  static const Color primary = Color(0xFF006A63);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF3AA89E);
  static const Color onPrimaryContainer = Color(0xFF003733);
  static const Color inversePrimary = Color(0xFF6FD8CD);
  static const Color secondary = Color(0xFFA7392A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFD7865);
  static const Color onSecondaryContainer = Color(0xFF701008);
  static const Color tertiary = Color(0xFF94492C);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFDA815F);
  static const Color onTertiaryContainer = Color(0xFF591D03);
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);
  static const Color primaryFixed = Color(0xFF8CF4E9);
  static const Color primaryFixedDim = Color(0xFF6FD8CD);
  static const Color onPrimaryFixed = Color(0xFF00201D);
  static const Color onPrimaryFixedVariant = Color(0xFF00504A);
  static const Color secondaryFixed = Color(0xFFFFDAD4);
  static const Color secondaryFixedDim = Color(0xFFFFB4A8);
  static const Color onSecondaryFixed = Color(0xFF410100);
  static const Color onSecondaryFixedVariant = Color(0xFF862116);
  static const Color tertiaryFixed = Color(0xFFFFDBCF);
  static const Color tertiaryFixedDim = Color(0xFFFFB59A);
  static const Color onTertiaryFixed = Color(0xFF380D00);
  static const Color onTertiaryFixedVariant = Color(0xFF763317);
  static const Color background = Color(0xFFF6FAF8);
  static const Color onBackground = Color(0xFF171D1C);
  static const Color surfaceVariant = Color(0xFFDFE3E2);
  static const Color backgroundWarm = Color(0xFFF7F4EC);
  static const Color surfaceMist = Color(0xFFCFE8E2);
  static const Color primaryPressed = Color(0xFF1E5E5A);
  static const Color accentGold = Color(0xFFFFC857);

  /// `colors.faded-mark-opacity` — primary (#006A63) at 45% alpha per design YAML.
  static const Color fadedMarkOpacity = Color(0x73006A63);
}
