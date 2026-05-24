import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Roles from `docs/design.md` frontmatter (`typography:`), via Google Fonts.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLg => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.02 * 32,
    color: AppColors.inkNavy,
  );

  static TextStyle get titleMd => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.inkNavy,
  );
  static TextStyle get titleSm => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.inkNavy,
  );
  static TextStyle get titleXs => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.inkNavy,
  );

  static TextStyle get headlineSm => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.inkNavy,
  );

  static TextStyle get bodyLg => GoogleFonts.nunitoSans(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyMd => GoogleFonts.nunitoSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: AppColors.onSurface,
  );

  static TextStyle get labelBold => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.05 * 14,
    color: AppColors.inkNavy,
  );

  static TextStyle get labelSm => GoogleFonts.nunitoSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    color: AppColors.onSurfaceVariant,
  );

  /// Maps design roles onto Material [TextTheme] slots for [ThemeData.textTheme].
  static TextTheme get materialTextTheme => TextTheme(
    displayLarge: displayLg,
    titleLarge: titleMd,
    headlineSmall: headlineSm,
    bodyLarge: bodyLg,
    bodyMedium: bodyMd,
    labelLarge: labelBold,
    labelSmall: labelSm,
  );
}
